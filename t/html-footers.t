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
{ $group_name } …<br />
{ $group_url } …<br />
Powered by Perl …<br />
EOF

  my $footer = Email::Footer->new({
    template => {
      html => {
        start_delim => '<div id="heavy-footer" style="width: auto; margin: 0">',
        end_delim   => '</div>',
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
          content_type => "text/html",
          encoding     => "quoted-printable",
          charset      => "UTF-8",
        },
        body_str => <<EOF,
<html>
<head><title>An email…</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
</body>
</html>
EOF
      ),
    ],
  );

  my $orig = $email->as_string;

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  # Use HTML::TreeBuilder to generate parsed versions
  # of both forms, then add whitespace after all html
  # tags

  my $t1 = HTML::TreeBuilder->new;
  $t1->no_space_compacting();

  my $t2 = HTML::TreeBuilder->new;
  $t2->no_space_compacting();

  my $got = $t1->parse_content($email->body_str)->as_HTML();
  $got =~ s/>/>\n/g;

  my $expect = $t2->parse_content(<<EOF)->as_HTML();
<html><head><title>An email…</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
<div id="heavy-footer" style="width: auto; margin: 0">
Better Faster Stronger …<br />
https://example.net/groups/bfs …<br />
Powered by Perl …<br />
</div>
</body>
</html>
EOF
  $expect =~ s/>/>\n/g;

  eq_or_diff(
    $got,
    $expect,
    "Footer looks right"
  );

  # Now strip the footer
  $footer->strip_footers($email);

  $t1 = HTML::TreeBuilder->new;
  $t1->no_space_compacting();

  $t2 = HTML::TreeBuilder->new;
  $t2->no_space_compacting();

  $got = $t1->parse_content($email->body_str)->as_HTML();
  $got =~ s/>/>\n/g;

  $expect = $t2->parse_content(<<EOF)->as_HTML();
<html><head><title>An email&hellip;</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
</body>
</html>
EOF
  $expect =~ s/>/>\n/g;

  eq_or_diff($got, $expect, 'string returned to original form');
};

subtest "quoted html footer removal" => sub {
  my $tfoot = <<'EOF';
{ $group_name } …<br />
{ $group_url } …<br />
Powered by Perl …<br />
EOF

  my $footer = Email::Footer->new({
    template => {
      html => {
        start_delim => '<div id="heavy-footer" style="width: auto; margin: 0">',
        end_delim   => '</div>',
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
          content_type => "text/html",
          encoding     => "quoted-printable",
          charset      => "UTF-8",
        },
        body_str => <<'EOF',
<div dir="ltr">Oh <b>boy</b><meta><br><div><div class="gmail_extra"><br><div class="gmail_quote">On Fri, Oct 28, 2016 at 1:02 PM,  <span dir="ltr">&lt;<a href="mailto:someone@example.net" target="_blank">someone@example.net</a>&gt;</span> wrote:<br><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex"><div><a href="https://example.net" target="_blank">Wow what an Email</a><div id="m_5048774373898288484heavy-footer" style="width:auto;margin:0">
Better Faster Stronger …<br>
<a href="https://example.net/groups/bfs" target="_blank">https://example.net/groups/bfs …</a><br>
Powered by Perl …<br>
</div>
</div>
</blockquote></div><br></div></div></div>
EOF
      ),
    ],
  );

  # Verify initial state
  for my $str (
    "Better Faster Stronger …",
    "https://example.net/groups/bfs …",
    "Powered by Perl …",
  ) {
    like(
      $email->body_str,
      qr/\Q$str\E/,
      "footer exits"
    );
  }

  # Now strip the footers
  $footer->strip_footers($email);

  # Verify these are now gone
  for my $str (
    "Better Faster Stronger …",
    "https://example.net/groups/bfs …",
    "Powered by Perl …",
  ) {
    unlike(
      $email->body_str,
      qr/\Q$str\E/,
      "footer cleared from quoted response"
    );
  }
};

subtest "Make sure match works based on style" => sub {
  # Stripping footer is based off of id='..' or style string.
  # Above tests work because id is correct. This test mangles
  # id to make sure style matching works

  my $tfoot = <<'EOF';
{ $group_name } …<br />
{ $group_url } …<br />
Powered by Perl …<br />
EOF

  my $footer = Email::Footer->new({
    template => {
      html => {
        start_delim => '<div id="heavy-footer" style="width: auto; margin: 0">',
        end_delim   => '</div>',
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
          content_type => "text/html",
          encoding     => "quoted-printable",
          charset      => "UTF-8",
        },
        body_str => <<'EOF',
<div dir="ltr">Oh <b>boy</b><br><div><div class="gmail_extra"><br><div class="gmail_quote">On Fri, Oct 28, 2016 at 1:02 PM,  <span dir="ltr">&lt;<a href="mailto:someone@example.net" target="_blank">someone@example.net</a>&gt;</span> wrote:<br><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex"><div><a href="https://example.net" target="_blank">Wow what an Email</a><div id="m_5048774373898288484broken-footer" style="width:auto;margin:0">
Better Faster Stronger …<br>
<a href="https://example.net/groups/bfs" target="_blank">https://example.net/groups/bfs …</a><br>
Powered by Perl …<br>
</div>
</div>
</blockquote></div><br></div></div></div>
EOF
      ),
    ],
  );

  # Verify initial state
  for my $str (
    "Better Faster Stronger …",
    "https://example.net/groups/bfs …",
    "Powered by Perl …",
  ) {
    like(
      $email->body_str,
      qr/\Q$str\E/,
      "footer exits"
    );
  }

  # Now strip the footers
  $footer->strip_footers($email);

  # Verify tese are now gone
  for my $str (
    "Better Faster Stronger …",
    "https://example.net/groups/bfs …",
    "Powered by Perl …",
  ) {
    unlike(
      $email->body_str,
      qr/\Q$str\E/,
      "footer cleared from quoted response"
    );
  }
};

subtest "ensure lines over 778 bytes aren't possible" => sub {
  my $long_line = "x" x 1024;

  my $tfoot = <<"EOF";
$long_line { \$group_name } …<br />
$long_line { \$group_url } …<br />
$long_line Powered by Perl …<br />
EOF

  my $footer = Email::Footer->new({
    template => {
      html => {
        start_delim => '<div id="heavy-footer" style="width: auto; margin: 0">',
        end_delim   => '</div>',
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
          content_type => "text/html",
          encoding     => "8bit", # This will keep our original line lengths
          charset      => "UTF-8",
        },
        body_str => <<EOF,
<html>
<head><title>An email&hellip;</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
</body>
</html>
EOF
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

  is(
    $email->header_str('Content-Transfer-Encoding'),
    'quoted-printable',
    'encoding changed'
  );

  # Double check that our footer adding/stripping still
  # works

  # Use HTML::TreeBuilder to generate parsed versions
  # of both forms, then add whitespace after all html
  # tags

  my $t1 = HTML::TreeBuilder->new;
  $t1->no_space_compacting();

  my $t2 = HTML::TreeBuilder->new;
  $t2->no_space_compacting();

  my $got = $t1->parse_content($email->body_str)->as_HTML();
  $got =~ s/>/>\n/g;

  my $expect = $t2->parse_content(<<"EOF")->as_HTML();
<html><head><title>An email&hellip;</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
<div id="heavy-footer" style="width: auto; margin: 0">
$long_line Better Faster Stronger …<br />
$long_line https://example.net/groups/bfs …<br />
$long_line Powered by Perl …<br />
</div>
</body>
</html>
EOF
  $expect =~ s/>/>\n/g;

  eq_or_diff(
    $got,
    $expect,
    "Footer looks right"
  );

  # Now strip the footer
  $footer->strip_footers($email);

  $t1 = HTML::TreeBuilder->new;
  $t1->no_space_compacting();

  $t2 = HTML::TreeBuilder->new;
  $t2->no_space_compacting();

  $got = $t1->parse_content($email->body_str)->as_HTML();
  $got =~ s/>/>\n/g;

  $expect = $t2->parse_content(<<EOF)->as_HTML();
<html><head><title>An email&hellip;</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
</body>
</html>
EOF
  $expect =~ s/>/>\n/g;

  eq_or_diff($got, $expect, 'string returned to original form');
};

subtest "no charset" => sub {
  my $tfoot = <<'EOF';
{ $group_name } …<br />
{ $group_url } …<br />
Powered by Perl …<br />
EOF

  my $footer = Email::Footer->new({
    template => {
      html => {
        start_delim => '<div id="heavy-footer" style="width: auto; margin: 0">',
        end_delim   => '</div>',
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
          encoding     => "quoted-printable",
          content_type => "text/html",
        },
        body => <<EOF,
<html>
<head><title>An email</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
</body>
</html>
EOF
      ),
    ],
  );

  my $orig = $email->as_string;

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  # Use HTML::TreeBuilder to generate parsed versions
  # of both forms, then add whitespace after all html
  # tags

  my $t1 = HTML::TreeBuilder->new;
  $t1->no_space_compacting();

  my $t2 = HTML::TreeBuilder->new;
  $t2->no_space_compacting();

  my $got = $t1->parse_content($email->body_str)->as_HTML();
  $got =~ s/>/>\n/g;

  my $expect = $t2->parse_content(<<EOF)->as_HTML();
<html><head><title>An email</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
<div id="heavy-footer" style="width: auto; margin: 0">
Better Faster Stronger …<br />
https://example.net/groups/bfs …<br />
Powered by Perl …<br />
</div>
</body>
</html>
EOF
  $expect =~ s/>/>\n/g;

  eq_or_diff(
    $got,
    $expect,
    "Footer looks right"
  );
};

subtest "pgp" => sub {
  my $message = path("t/corpus/html-mime-pgp.msg")->slurp;
  ok($message, 'got mime-pgp message');

  my $tfoot = <<'EOF';
{ $group_name }<br />
{ $group_url }<br />
Powered by Perl<br />
EOF

  my $footer = Email::Footer->new({
    template => {
      html => {
        start_delim => '<div id="heavy-footer" style="width: auto; margin: 0">',
        end_delim   => '</div>',
        template    => $tfoot,
      },
    },
  });

  my $email = Email::MIME->new($message);

  my @parts;
  $email->walk_parts(sub { push @parts, shift; });

  is(@parts, 3, 'got two parts');
  like($parts[0]->content_type, qr/multipart\/signed/, 'first part is signed');
  like($parts[1]->content_type, qr/text\/html/, 'second part is text');
  like($parts[2]->content_type, qr/application\/pgp/, 'third part is pgp');

  my $orig_signed_body = $parts[1]->body_str;
  like($orig_signed_body, qr/been pretty lazy/, 'got body text');

  $footer->add_footers($email, {
    group_name => "Better Faster Stronger",
    group_url  => "https://example.net/groups/bfs",
  });

  @parts = ();
  $email->walk_parts(sub { push @parts, shift; });

  is(@parts, 5, 'got 5 parts');
  like($parts[0]->content_type, qr/multipart\/mixed/, 'first part is mixed');
  like($parts[1]->content_type, qr/multipart\/signed/, 'second part is signed');
  like($parts[2]->content_type, qr/text\/html/, 'third part is html');
  like($parts[3]->content_type, qr/application\/pgp/, 'fourth part is pgp');
  like($parts[4]->content_type, qr/text\/html/, 'fifth part is html');

  eq_or_diff(
    $parts[2]->body_str,
    $orig_signed_body,
    'signed body was not modified'
  );

  my $expect = <<EOF;
<html><div id="heavy-footer" style="width: auto; margin: 0">
Better Faster Stronger<br />
https://example.net/groups/bfs<br />
Powered by Perl<br />
</div>
</html>
EOF

  # Kill final newline
  $expect =~ s/\r?\n\z//;

  my $foot = $parts[4]->body_str;
  $foot =~ s/\r\n/\n/g;

  eq_or_diff(
    $foot,
    $expect,
    "Footer part looks right"
  );

  # Now attempt to strip the footer from a message containing it
  $message = path("t/corpus/html-mime-pgp-with-footer.msg")->slurp;
  ok($message, 'got mime-pgp message');

  $email = Email::MIME->new($message);

  @parts = ();
  $email->walk_parts(sub { push @parts, shift; });

  $orig_signed_body = $parts[1]->body_str;

  # This should do nothing
  $footer->strip_footers($email);

  @parts = ();
  $email->walk_parts(sub { push @parts, shift; });

  is(@parts, 3, 'got 3 parts');
  like($parts[0]->content_type, qr/multipart\/signed/, 'firs part is signed');
  like($parts[1]->content_type, qr/text\/html/, 'second part is html');
  like($parts[2]->content_type, qr/application\/pgp/, 'third part is pgp');

  eq_or_diff(
    $parts[1]->body_str,
    $orig_signed_body,
    'signed body was not modified by strip_footers'
  );
};

done_testing;
