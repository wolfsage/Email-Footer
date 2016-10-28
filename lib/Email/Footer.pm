use 5.008001;
use strict;
use warnings;

package Email::Footer;
# ABSTRACT: Add/strip footers from email messages
use Moose;

use Module::Find;
use Module::Runtime;

use Carp qw(croak);
use Try::Tiny;
use Text::Quoted;
use HTML::TreeBuilder;

use namespace::autoclean;

has renderer => (
  is   => 'ro',
  isa  => 'Str',
  default => 'Text::Template',
);

has renderer_object => (
  is       => 'ro',
  does     => 'Email::Footer::Renderer',
  init_arg => undef,
  lazy     => 1,
  default  => sub { $_[0]->_build_component("Renderer", $_[0]->renderer) },
);

has _rws => (
  is       => 'ro',
  traits   => [ 'Array' ],
  handles  => {
    add_rw => 'push',
    rws    => 'elements',
  },
  init_arg => undef,
  default  => sub { [] },
);

has template => (
  is   => 'ro',
  isa  => 'HashRef[HashRef]',
  required => 1,
);

sub _tree_builder {
  my $tree = HTML::TreeBuilder->new;

  $tree->no_space_compacting(1);

  return $tree;
}

sub text_template {
  my ($self) = @_;

  return $self->template->{text};
}

sub html_template {
  my ($self) = @_;

  return $self->template->{html};
}

my $CRLF = qr/(?:\r\n|((?<!\r)\n))/;

sub BUILD {
  my ($self) = @_;

  unless (
       $self->text_template
    || $self->html_template
  ) {
    croak "An email or text template is required";
  }

  $self->_validate_template($self->text_template, 'text_template');
  $self->_validate_template($self->html_template, 'html_template');

  # Make sure all parts end with no line breaks
  if ($self->text_template) {
    $_ =~ s/$CRLF*\z//g for (
      $self->text_template->{start_delim},
      $self->text_template->{end_delim},
      $self->text_template->{template},
    );
  }

  if ($self->html_template) {
    $_ =~ s/$CRLF*\z//g for (
      $self->html_template->{start_delim},
      $self->html_template->{end_delim},
      $self->html_template->{template},
    );

    my $tree = $self->_tree_builder;
    $tree->parse_content($self->html_template->{start_delim});

    my $div = $tree->look_down('_tag' => 'div');
    unless ($div) {
      croak("html_template start_delim must contain a start <div>")
    }

    my $id = $div->attr('id');
    unless ($id) {
      croak("html_template start_delim div must have an 'id' attribute");
    }

    $self->html_template->{start_delim_id_re} = qr/\Q$id\E/i;

    my $style = $div->attr('style');
    unless ($style) {
      croak("html_template start_delim div must have a 'style' attribute");
    }

    # Remove all whitespace. When we compare we'll do the same. This is
    # becuase some MUAs are evil and do this for some bizarre reason
    $style =~ s/\s+//g;

    $self->html_template->{start_delim_style} = qr/\Q$style\E/i;
  }

  for my $rw (findallmod 'Email::Footer::RW') {
    my $c = $self->_build_component(undef, $rw);

    $self->add_rw($c);
  }

  $self->renderer_object;
}

sub _validate_template {
  my ($self, $template, $type) = @_;

  return unless $template;

  my %expect = map { $_ => 1 } qw(start_delim end_delim template);

  my @missing;
  my @extra;

  for my $k (keys %expect) {
    push @missing, $k unless exists $template->{$k};
  }

  for my $k (keys %$template) {
    unless ($expect{$k}) {
      push @extra, $k;
    }
  }

  if (@extra || @missing) {
    croak("Template '$type' incorrect: Missing '@missing', extra '@extra'");
  }
}

sub _build_component {
  my ($self, $prefix, $component, $arg) = @_;

  $arg //= {};

  if ($prefix) {
    $component = $prefix . "::" . $component;
  }

  unless ($component =~ /^Email::Footer::/) {
    $component = 'Email::Footer::' . $component;
  }

  try {
    Module::Runtime::require_module($component);
  } catch {
    croak("Component $component failed to load: $_");
  };

  $component->new({ %$arg, footer => $self });
}

sub _find_rw_for {
  my ($self, $email) = @_;

  for my $rw ($self->rws) {
    if ($rw->can_handle($email)) {
      return $rw;
    }
  }
}

sub add_footers {
  my ($self, $email, $arg) = @_;

  my $rw = $self->_find_rw_for($email) or croak(
    "Installed RWs cannot understand provided email"
  );

  my $text_adder;
  if ($self->text_template) {
    my $footer =   $self->text_template->{start_delim}
                 . "\n"
                 . $self->renderer_object->render(
                     $self->text_template->{template}, $arg,
                   )
                 . "\n"
                 . $self->text_template->{end_delim}
                 . "\n";


    # Make all line endings \n
    $footer =~ s/$CRLF/\n/g;

    $text_adder = sub {
      my $text = shift;

      $$text .= "\n" . $footer;
    };
  }

  my $html_adder;
  if ($self->html_template) {
    my $footer =   $self->html_template->{start_delim}
                 . "\n"
                 . $self->renderer_object->render(
                     $self->html_template->{template}, $arg,
                   )
                 . "\n"
                 . $self->html_template->{end_delim}
                 . "\n";

    $footer =~ s/$CRLF/\n/g;

    $html_adder = sub {
      my $text = shift;

      my $tree = try {
        my $tree = $self->_tree_builder;

        $tree->parse_content($$text);

        $tree;
      };

      if ($tree && (my $body = $tree->look_down('_tag' => 'body'))) {
        $body->push_content(
          HTML::Element->new('~literal', text => $footer)
        );

        $$text = $tree->as_HTML();
      }
    };
  }

  $rw->walk_parts($email, $text_adder, $html_adder);

  return;
}

sub strip_footers {
  my ($self, $email) = @_;

  my $rw = $self->_find_rw_for($email) or croak(
    "Installed RWs cannot understand provided email"
  );

  my $text_stripper;
  if ($self->text_template) {
    my $start_del = $self->text_template->{start_delim};
    my $end_del = $self->text_template->{end_delim};

    my $matcher = qr/
      $CRLF
      ^ \Q$start_del\E $CRLF
      .*?
      ^ \Q$end_del\E ($CRLF|\z)
    /msx;

    $text_stripper = sub {
      my $text = shift;

      $$text =~ s/$matcher//g;

      $self->_strip_text_footers($matcher, $text);
    };
  }

  my $html_stripper;
  if ($self->html_template) {
    $html_stripper = sub {
      my $text = shift;

      my $tree = try {
        my $tree = $self->_tree_builder;

        $tree->parse_content($$text);

        $tree;
      };

      return unless $tree;

      for my $child ($tree->look_down(sub {
        my $style = lc ($_[0]->attr('style') || '');
        $style =~ s/\s+//g;

        return
             ($_[0]->attr('id') || '') =~ $self->html_template->{start_delim_id_re}
          || index($style, $self->html_template->{start_delim_style}) > -1
      })) {
        $child->delete;
      }

      $$text = $tree->as_HTML();
    };
  }

  $rw->walk_parts($email, $text_stripper, $html_stripper);

  return;
}

sub _strip_text_footer_helper {
  my ($self, $matcher, $input) = @_;

  if (ref $input eq 'ARRAY') {
    my @base;
    for (my $i = 0; $i < @$input; $i++) {
      if (ref $input->[$i] eq 'ARRAY') {
        push @base, $input->[$i];
        next;
      }

      my $merge = $input->[$i];
      delete $merge->{empty};
      delete $merge->{separator};

      while ($input->[$i+1] && ref $input->[$i+1] eq 'HASH') {
        $i++;
        $merge->{text} .= "\n" . $input->[$i]{text};
        $merge->{raw}  .= "\n" . $input->[$i]{raw};
      }

      push @base, $merge;
    }

    return [ map {; $self->_strip_text_footer_helper($matcher, $_) } @base ];

    return [ map {; $self->_strip_text_footer_helper($matcher, $_) } @$input ];
  }

  if ($input->{text}) {
    if ($input->{text} =~ s/$matcher//g) {
      return unless $input->{text};

      # Ripping out the footer tends to leave long runs of whitespace.  Trim
      # them down to something slightly less jarring. -- rjbs, 2015-06-25
      $input->{text} =~ s/$CRLF$CRLF$CRLF+/\n\n/g;

      $input->{raw} = $input->{text};

      my $quoter = $input->{quoter} || '';
      $input->{raw} =~ s/^/$quoter /gm;
      chomp $input->{raw};
    }
  }

  return $input;
}

sub _strip_text_footers {
  my ($self, $matcher, $content_ref) = @_;

  # XXX - Bail out early if we don't match our starting delim?
  #       -- alh, 2016-10-28
  my $quoted = Text::Quoted::extract($$content_ref);

  my $stripped = $self->_strip_text_footer_helper($matcher, $quoted);

  # combine_hunks adds a trailing newline. Don't put it there
  # unless we expected one
  my $nl = $$content_ref =~ /\n\z/;

  $$content_ref = Text::Quoted::combine_hunks( $stripped );

  $$content_ref =~ s/\n\z// unless $nl;

  return;
}


1;
__END__
