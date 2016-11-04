use 5.008001;
use strict;
use warnings;

package Email::Footer::Test::Dir;

use Moose;
use JSON;
use Try::Tiny;

has json_codec => (
  is => 'ro',
  isa => 'JSON',
  default => sub { JSON->new->pretty->utf8; },
  handles => { 'decode_json' => 'decode' },
);

has 'root_dir' => (
  is => 'ro',
  isa => 'Path::Tiny',
  required => 1,
);

has 'input_msg' => (
  is => 'ro',
  isa => 'Path::Tiny',
  required => 1,
);

has 'input_message' => (
  is => 'ro',
  isa => 'Email::Abstract',
  init_arg => undef,
  lazy => 1,
  builder => '_build_input_message',
);

has 'output_msg' => (
  is => 'ro',
  isa => 'Path::Tiny',
  required => 1,
);

has 'output_message' => (
  is => 'ro',
  isa => 'Email::Abstract',
  init_arg => undef,
  lazy => 1,
  builder => '_build_output_message',
);

has 'template_json' => (
  is => 'ro',
  isa => 'Path::Tiny',
  required => 1,
);

has 'template_arg' => (
  is => 'ro',
  isa => 'HashRef',
  init_arg => undef,
  lazy => 1,
  builder => '_build_template_arg',
);

has 'shortdesc_txt' => (
  is => 'ro',
  isa => 'Path::Tiny',
  required => 1,
);

has 'shortdesc_text' => (
  is => 'ro',
  isa => 'Str',
  init_arg => undef,
  lazy => 1,
  builder => '_build_shortdesc_text',
);

sub _build_input_message {
  my $self = shift;

  return Email::Abstract->new(Email::MIME->new($self->input_msg->slurp));
}

sub _build_output_message {
  my $self = shift;

  return Email::Abstract->new(Email::MIME->new($self->output_msg->slurp));
}

sub _build_template_arg {
  my $self = shift;

  my $arg = $self->decode_json($self->template_json->slurp);
  my $template = delete $arg->{template} || die "No 'template' arg in JSON!\n";
  my $values = delete $arg->{values} || die "No 'values' arg in JSON!\n";

  if (my @extra = keys %$arg) {
    warn "Ignoring extra arguments in JSON (@extra)\n";
  }

  return {
    template => $template,
    values   => $values,
  }
}

sub _build_shortdesc_text {
  my $self = shift;

  return $self->shortdesc_txt->slurp;
}

around BUILDARGS => sub {
  my $orig  = shift;
  my $class = shift;
  my $arg   = shift;

  for my $k (keys %$arg) {
    my $new = $k;
    $new =~ s/\./_/g;
    $arg->{$new} = delete $arg->{$k};
  }

  return $class->$orig($arg);
};

sub BUILD {
  my $self = shift;

  # Make sure these are sane
  try {
    $self->$_ for qw(input_message output_message template_arg shortdesc_text);
  } catch {
    die "Failed to compile test object for dir " . $self->root_dir . ": $_\n";
  }
}

1;
