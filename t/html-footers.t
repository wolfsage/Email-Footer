use strict;
use warnings;

use Email::MIME;
use Email::Footer;

use Test::More;
use Test::Differences;

subtest "basic text footer add/removal" => sub {
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

  my $got = $t1->parse_content($email->body)->as_HTML();
  $got =~ s/>/>\n/g;

  my $expect = $t2->parse_content(<<EOF)->as_HTML();
<html><head><title>An email</title></head>
<body>
  <a href="https://example.net">Wow what an Email</a>
<div id="heavy-footer" style="width: auto; margin: 0">
Better Faster Stronger<br />
https://example.net/groups/bfs<br />
Powered by Perl<br />
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

  $got = $t1->parse_content($email->body)->as_HTML();
  $got =~ s/>/>\n/g;

  $expect = $t2->parse_content(<<EOF)->as_HTML();
<html><head><title>An email</title></head>
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
<div dir="ltr">Oh <b>boy</b><br><div><div class="gmail_extra"><br><div class="gmail_quote">On Fri, Oct 28, 2016 at 1:02 PM,  <span dir="ltr">&lt;<a href="mailto:someone@example.net" target="_blank">someone@example.net</a>&gt;</span> wrote:<br><blockquote class="gmail_quote" style="margin:0 0 0 .8ex;border-left:1px #ccc solid;padding-left:1ex"><div><a href="https://example.net" target="_blank">Wow what an Email</a><div id="m_5048774373898288484heavy-footer" style="width:auto;margin:0">
Better Faster Stronger<br>
<a href="https://example.net/groups/bfs" target="_blank">https://example.net/groups/bfs</a><br>
Powered by Perl<br>
</div>
</div>
</blockquote></div><br></div></div></div>
EOF
      ),
    ],
  );

  # Verify initial state
  for my $str (
    "Better Faster Stronger",
    "https://example.net/groups/bfs",
    "Powered by Perl",
  ) {
    like(
      $email->as_string,
      qr/\Q$str\E/,
      "footer exits"
    );
  }

  # Now strip the footers
  $footer->strip_footers($email);

  # Verify initial state
  for my $str (
    "Better Faster Stronger",
    "https://example.net/groups/bfs",
    "Powered by Perl",
  ) {
    unlike(
      $email->as_string,
      qr/\Q$str\E/,
      "footer cleared from quoted response"
    );
  }
};

done_testing;
