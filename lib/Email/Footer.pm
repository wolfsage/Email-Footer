use 5.008001;
use strict;
use warnings;

package Email::Footer;
# ABSTRACT: Add/strip footers from email messages
use Moose;

use Module::Find;
use Module::Runtime;

use Try::Tiny;

use Carp qw(croak);

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

sub text_template {
  my ($self) = @_;

  return $self->template->{text};
}

sub html_template {
  my ($self) = @_;

  return $self->template->{html};
}

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
    $_ =~ s/(\r?\n)*\z//g for (
      $self->text_template->{start_delim},
      $self->text_template->{end_delim},
      $self->text_template->{template},
    );
  }

  if ($self->html_template) {
    $_ =~ s/(\r?\n)*\z//g for (
      $self->html_template->{start_delim},
      $self->html_template->{end_delim},
      $self->html_template->{template},
   );
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
                 . "\r\n"
                 . $self->renderer_object->render(
                     $self->text_template->{template}, $arg,
                   )
                 . "\r\n"
                 . $self->text_template->{end_delim}
                 . "\r\n";


    $footer =~ s/(?<!\r)\n/\r\n/g;

    $text_adder = sub {
      my $text = shift;

      $$text .= "\r\n" . $footer;
    };
  }

  my $html_adder;
  if ($self->html_template) {
    my $footer =   $self->html_template->{start_delim}
                 . "\r\n"
                 . $self->renderer_object->render(
                     $self->html_template->{template}, $arg,
                   )
                 . "\r\n"
                 . $self->html_template->{end_delim}
                 . "\r\n";

    $footer =~ s/(?<!\r)\n/\r\n/g;

    $html_adder = sub {
      my $text = shift;

      $$text .= $footer;
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
      \r?\n?
      ^ \Q$start_del\E \r?$
      .*?
      ^ \Q$end_del\E \r?$
      \r?\n?
    /msx;

    $text_stripper = sub {
      my $text = shift;

      $$text =~ s/$matcher//g;
    };
  }

  my $html_stripper;
  if ($self->html_template) {
    $html_stripper = sub {

    };
  }

  $rw->walk_parts($email, $text_stripper, $html_stripper);

  return;
}

1;
__END__
