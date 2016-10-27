#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(lib);

use Email::MIME;
use Email::Footer;

my $tfoot = <<'EOF';
{ $group_name }
{ $group_url }
EOF

my $footer = Email::Footer->new({
  template => {
    text => {
      start_delim => ('-' x 42),
      end_delim   => "Powered by Perl",
      template    => $tfoot,
    },
  },
});

my $email = Email::MIME->create(
  header_str => [
    From => 'my@address',
    To   => 'your@address',
  ],
  parts => [
    q[This is part one. It is a lonely part.],
  ],
);

my $orig = $email->as_string;

$footer->add_footers($email, {
  group_name => "Better Faster Stronger",
  group_url  => "https://example.net/groups/bfs",
});

print "With footers\n\n";

print $email->as_string . "\n";

$footer->strip_footers($email);

if ($orig eq $email->as_string) {
  print "Email returned to normal\n";
} else {
  print "Email changed?!\n";
}

# Now test removing from quoted text

$footer->add_footers($email, {
  group_name => "Better Faster Stronger",
  group_url  => "https://example.net/groups/bfs",
});

$email->walk_parts(sub {
  my ($part) = @_;
  return if $part->subparts; # multipart

  if ( $part->content_type =~ m[text/plain]i ) {
    my $body = $part->body;

    # Quote the message
    $body =~ s/^/> /mg;

    $part->body_set( "Top posted response OH NO!\r\n\r\n$body" );
  }
});

print "\nQuoted response\n";
print $email->as_string;

$footer->strip_footers($email);
print "\nStripped\n";
print $email->as_string;

__END__

$ perl test.pl
With footers

From: my@address
To: your@address
Date: Thu, 27 Oct 2016 13:37:18 -0400
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Type: text/plain

This is part one. It is a lonely part.
------------------------------------------
Better Faster Stronger
https://example.net/groups/bfs
Powered by Perl
Email returned to normal
