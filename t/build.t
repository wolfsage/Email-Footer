use strict;
use warnings;

use Email::Footer;

use Test::More;

my %t = (
  template => {
    text => {
      start_delim => 'start',
      template => "",
      end_delim => 'end'
    },
  },
);

my @ok = (
  { %t, renderer => 'Text::Template' },
  { %t, renderer => 'Email::Footer::Renderer::Text::Template' },
  { %t, rws => [ 'Email::MIME', 'Email::Footer::Renderer::Email::MIME' ], },
);

for my $arg (@ok) {
  ok(Email::Footer->new($arg), "Created an Email::Footer object");
}

done_testing;
