use 5.008001;
use strict;
use warnings;

package Email::Footer::Test;

use Moose;

use Path::Tiny;
use File::ShareDir qw(dist_dir);
use List::Util qw(any);
use Email::MIME;
use Email::Abstract;
use Test::More;
use Test::Deep qw(cmp_deeply);
use Test::Differences;
use Try::Tiny;

use Email::Footer;
use Email::Footer::Test::Dir;

has dir => (
  is => 'ro',
  isa => 'Str',
);

has rws => (
  is => 'ro',
  isa => 'ArrayRef',
  default => sub { [ 'Email::MIME' ] },
);

has renderers => (
  is => 'ro',
  isa => 'ArrayRef',
  default => sub { [ 'Text::Template' ] },
);

sub run_all_tests {
  my $self = shift;

  my @configurations;

  for my $renderer (@{ $self->renderers }) {
    for my $rw (@{ $self->rws }) {
      push @configurations, {
        renderer => $renderer,
        rws      => [ $rw ],
      };
    }
  }

  my @tests = $self->collect_tests;
  ok(@tests, 'got some tests to run');

  for my $configuration (@configurations) {
    for my $test (@tests) {
      $self->run_one_test($configuration, $test);
    }
  }
}

sub collect_tests {
  my $self = shift;

  my $dir = $self->dir;

  if ($dir) {
    $dir = path($dir);
  } else {
    $dir = path(dist_dir('Email-Footer'));
  }

  my $tdir = $dir->child('t')->child('corpus');

  $self->_collect_tests($tdir);
}

sub _collect_tests {
  my $self = shift;
  my $dir = shift;

  my @tests;
  my %expect = map { $_ => 1 } qw(
    input.msg
    output.msg
    shortdesc.txt
    template.json
  );

  # We are in a final level test directory? 
  if (any { /(input\.msg|output\.msg)/ } $dir->children) {
    my %got = map { $_->basename => $_ } $dir->children;

    my %final;

    for my $k (keys %expect) {
        $final{$k} = delete $got{$k} if exists $got{$k};
    }

    my @missing = grep { ! exists $final{$_} } keys %expect;
    my @extra = grep { ! exists $expect{$_} || /README/ } keys %got;
 
    if (@extra) {
      warn "Extra files in $dir found, ignoring these: (@extra)\n";
    }

    if (@missing) {
      warn "Missing files in $dir, ignoring test. (Missing @missing)\n";
    } else {
      my $test = try {
        Email::Footer::Test::Dir->new({ %final, root_dir => $dir });
      } catch {
        warn "$_, skipping...\n";
      };

      push @tests, $test if $test;
    }
  } else {
    for my $file ($dir->children) {
      if ($file->is_dir) {
        push @tests, $self->_collect_tests($file) if $file->is_dir;
      } else {
        warn "Skipping $file, expected directory, got something else\n";
      }
    }
  }

  unless (@tests) {
    warn "Found no tests in $dir\n";
  }

  return @tests;
}

sub run_one_test {
  my $self = shift;
  my $configuration = shift;
  my $test = shift;

  my $footer = Email::Footer->new({
    %$configuration,
    template => $test->template_arg->{template},
  });

  my $name = $test->shortdesc_text . "(" . $test->root_dir . ")";

  subtest "$name" => sub {
    my $start = $test->input_message->cast($configuration->{rws}[0]);
    my $end = $test->output_message->cast($configuration->{rws}[0]);

    ok($start, 'got a start');

    $footer->strip_footers($start);
    $footer->add_footers($start, $test->template_arg->{values});

    my $got = Email::Abstract->new($start)->cast('Email::MIME');
    my $expect = Email::Abstract->new($end)->cast('Email::MIME');

    my @gparts;
    $got->walk_parts(sub { push @gparts, shift });

    my @eparts;
    $expect->walk_parts(sub { push @eparts, shift });

    is(
      0+@gparts,
      0+@eparts,
      "Got the correct number of parts"
    );

    my $fail = 0;

    for my $i (0..$#gparts) {
      my $gpart = $gparts[$i];
      my $epart = $eparts[$i];

      my ($gct) = $gpart->content_type =~ /^(.*?)(;|\s|$)/;
      my ($ect) = $epart->content_type =~ /^(.*?)(;|\s|$)/;

      is(
        $gct,
        $ect,
        "Content type for part $i matches ($gct)"
      ) or $fail++;

      is(
        0 + $gpart->subparts,
        0 + $epart->subparts,
        "Part $i has right number of subarts"
      ) or $fail++;

      unless ($gpart->subparts) {
        my $gpart_body = do {
          $gpart->content_type =~ /text\/(plain|html)/i
            ? $gpart->body_str
            : $gpart->body_raw
        };
        my $epart_body = do {
          $epart->content_type =~ /text\/(plain|html)/i
            ? $epart->body_str
            : $epart->body_raw
        };
        $gpart_body =~ s/\r\n/\n/g;
        $epart_body =~ s/\r\n/\n/g;

        unified_diff;
        eq_or_diff_text(
          $gpart_body,
          $epart_body,
          "Body for part $i matches"
        ) or $fail++;
      }
    }

    if ($fail) {
      diag "GOT:\n" . $got->as_string;
      diag "EXPECT:\n" . $expect->as_string;
    }
  };
}

1;
