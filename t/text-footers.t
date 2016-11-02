use strict;
use warnings;

use Email::MIME;
use Email::Footer;

use Test::More;
use Test::Differences;

use Path::Tiny;
use List::Util qw(max);

use utf8;

subtest "basic text footer add/removal" => sub {
  my $tfoot = <<'EOF';
{ $group_name } …
{ $group_url } …
EOF

  my $footer = Email::Footer->new({
    template => {
      text => {
        start_delim => ('-' x 42),
        end_delim   => "Powered by Perl …",
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
      Email::MIME->create(
        attributes => {
          content_type => "text/plain",
          encoding     => "quoted-printable", # This will keep our original line lengths
          charset      => "UTF-8",
        },
        body_str => "This is part one. It is a lonely part…\n",
      ),
    ],
  );

  my $orig = $email->as_string;

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  my $body = $email->body_str;
  $body =~ s/\r\n/\n/g;

  eq_or_diff(
    $body,
    <<'EOF',
This is part one. It is a lonely part…

------------------------------------------
Better Faster Stronger …
https://example.net/groups/bfs …
Powered by Perl …
EOF
    "Footer looks right"
  );

  # Now strip the footer
  $footer->strip_footers($email);

  my $email_str = $email->as_string;
  $orig =~ s/\r\n/\n/g;
  $email_str =~ s/\r\n/\n/g;
  $orig =~ s/7bit/quoted-printable/;

  eq_or_diff($email_str, $orig, 'string returned to original form');
};

subtest "quoted footer removal" => sub {
  my $tfoot = <<'EOF';
{ $group_name } …
{ $group_url } …
EOF

  my $footer = Email::Footer->new({
    template => {
      text => {
        start_delim => ('-' x 42),
        end_delim   => "Powered by Perl …",
        template    => $tfoot,
      },
    },
  });

  # On an originally us-ascii email
  my $email = Email::MIME->create(
    header_str => [
      From => 'my@address',
      To   => 'your@address',
    ],
    parts => [
      "This is part one. It is a lonely part\n",
    ],
  );

  my $orig = $email->as_string;

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  my $body = $email->body_str;
  $body =~ s/\r\n/\n/g;

  eq_or_diff(
    $body,
    <<'EOF',
This is part one. It is a lonely part

------------------------------------------
Better Faster Stronger …
https://example.net/groups/bfs …
Powered by Perl …
EOF
    "Footer looks right"
  );

  # Pretend someone responded and quoted our email
  $email->walk_parts(sub {
    my ($part) = @_;
    return if $part->subparts; # multipart

    if ( $part->content_type =~ m[text/plain]i ) {
      my $body = $part->body_str;

      # Quote the message
      $body =~ s/^/> /mg;

      $part->body_str_set( "Top posted response… OH NO!\n\n$body" );
    }
  });

  # Check our assumptions
  $body = $email->body_str;
  $body =~ s/\r\n/\n/g;

  eq_or_diff(
    $body,
    <<EOF,
Top posted response… OH NO!

> This is part one. It is a lonely part
> 
> ------------------------------------------
> Better Faster Stronger …
> https://example.net/groups/bfs …
> Powered by Perl …
EOF
  'modified message looks right'
  );

  $footer->strip_footers($email);

  $body = $email->body_str;
  $body =~ s/\r\n/\n/g;

  eq_or_diff(
    $body,
    <<EOF,
Top posted response… OH NO!

> This is part one. It is a lonely part
EOF
  'stripped footers from quoted text'
  );
};

subtest "ensure lines over 778 bytes aren't possible" => sub {
  my $long_line = "x" x 1024;

  my $tfoot = <<"EOF";
$long_line { \$group_name } …
$long_line { \$group_url } …
EOF

  my $footer = Email::Footer->new({
    template => {
      text => {
        start_delim => ('-' x 42),
        end_delim   => "Powered by Perl …",
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
      Email::MIME->create(
        attributes => {
          content_type => "text/plain",
          encoding     => "8bit", # This will keep our original line lengths
          charset      => "UTF-8",
        },
        body_str => "This is part one. It is a lonely part…\n",
      ),
    ],
  );

  my $orig = $email->as_string;

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  my $max_length = max (
    map {
      length $_
    } split(/\r?\n/, $email->as_string)
  );

  cmp_ok($max_length, '<', 778, "Email rewritten safely");

  my $body = $email->body_str;
  $body =~ s/\r\n/\n/g;

  eq_or_diff(
    $body,
    <<"EOF",
This is part one. It is a lonely part…

------------------------------------------
$long_line Better Faster Stronger …
$long_line https://example.net/groups/bfs …
Powered by Perl …
EOF
    "Footer looks right"
  );

  # Now strip the footer
  $footer->strip_footers($email);

  my $email_str = $email->as_string;
  $orig =~ s/\r\n/\n/g;
  $email_str =~ s/\r\n/\n/g;

  $orig =~ s/8bit/quoted-printable/;
  $orig =~ s/\xe2\x80\xa6/=E2=80=A6/;# 8bit -> quoted-printable

  eq_or_diff($email_str, $orig, 'string returned to original form');
};

subtest "pgp" => sub {
  my $message = path("t/corpus/text-mime-pgp.msg")->slurp;
  ok($message, 'got mime-pgp message');

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

  my $email = Email::MIME->new($message);

  my @parts;
  $email->walk_parts(sub { push @parts, shift; });

  is(@parts, 3, 'got two parts');
  like($parts[0]->content_type, qr/multipart\/signed/, 'first part is signed');
  like($parts[1]->content_type, qr/text\/plain/, 'second part is text');
  like($parts[2]->content_type, qr/application\/pgp/, 'third part is pgp');

  my $orig_signed_body = $parts[1]->body_str;
  like($orig_signed_body, qr/been pretty lazy/, 'got body text');

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  @parts = ();
  $email->walk_parts(sub { push @parts, shift; });

  is(@parts, 4, 'got four parts');
  like($parts[0]->content_type, qr/multipart\/signed/, 'first part is signed');
  like($parts[1]->content_type, qr/text\/plain/, 'second part is text');
  like($parts[2]->content_type, qr/application\/pgp/, 'third part is pgp');
  like($parts[3]->content_type, qr/text\/plain/, 'fourth part is text');

  eq_or_diff(
    $parts[1]->body_str,
    $orig_signed_body,
    'signed body was not modified'
  );

  my $expect = <<EOF;

------------------------------------------
Better Faster Stronger
https://example.net/groups/bfs
Powered by Perl
EOF

  my $foot = $parts[3]->body_str;
  $foot =~ s/\r\n/\n/g;

  eq_or_diff(
    $foot,
    $expect,
    "Footer part looks right"
  );

  # Now strip the footer (which will do nothing since the message
  # is signed)
  $footer->strip_footers($email);

  @parts = ();
  $email->walk_parts(sub { push @parts, shift; });

  is(@parts, 4, 'got four parts');
  like($parts[0]->content_type, qr/multipart\/signed/, 'first part is signed');
  like($parts[1]->content_type, qr/text\/plain/, 'second part is text');
  like($parts[2]->content_type, qr/application\/pgp/, 'third part is pgp');
  like($parts[3]->content_type, qr/text\/plain/, 'fourth part is text');

  eq_or_diff(
    $parts[1]->body_str,
    $orig_signed_body,
    'signed body was not modified'
  );

  $foot = $parts[3]->body_str;
  $foot =~ s/\r\n/\n/g;

  eq_or_diff(
    $foot,
    $expect,
    "Footer part looks right"
  );
};

done_testing;
