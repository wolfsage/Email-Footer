use strict;
use warnings;

use Email::MIME;
use Email::Footer;

use Test::More;
use Test::Differences;

subtest "basic text footer add/removal" => sub {
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
      "This is part one. It is a lonely part.\n",
    ],
  );

  my $orig = $email->as_string;

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  eq_or_diff(
    $email->body,
    <<'EOF',
This is part one. It is a lonely part.

------------------------------------------
Better Faster Stronger
https://example.net/groups/bfs
Powered by Perl
EOF
    "Footer looks right"
  );

  # Now strip the footer
  $footer->strip_footers($email);

  eq_or_diff($email->as_string, $orig, 'string returned to original form');
};

subtest "quoted footer removal" => sub {
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
      "This is part one. It is a lonely part.\n",
    ],
  );

  my $orig = $email->as_string;

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  eq_or_diff(
    $email->body,
    <<'EOF',
This is part one. It is a lonely part.

------------------------------------------
Better Faster Stronger
https://example.net/groups/bfs
Powered by Perl
EOF
    "Footer looks right"
  );

  # Pretend someone responded and quoted our email
  $email->walk_parts(sub {
    my ($part) = @_;
    return if $part->subparts; # multipart

    if ( $part->content_type =~ m[text/plain]i ) {
      my $body = $part->body;

      # Quote the message
      $body =~ s/^/> /mg;

      $part->body_set( "Top posted response OH NO!\n\n$body" );
    }
  });

  # Check our assumptions
  eq_or_diff(
    $email->body,
    <<EOF,
Top posted response OH NO!

> This is part one. It is a lonely part.
> 
> ------------------------------------------
> Better Faster Stronger
> https://example.net/groups/bfs
> Powered by Perl
EOF
  'modified message looks right'
  );

  $footer->strip_footers($email);

  eq_or_diff(
    $email->body,
    <<EOF,
Top posted response OH NO!

> This is part one. It is a lonely part.
EOF
  'stripped footers from quoted text'
  );
};

done_testing;
