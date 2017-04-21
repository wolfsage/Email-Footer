package Email::Footer::RW::Email::MIME;

use Moose;

use Email::MIME;
use MIME::Entity;
use Email::Abstract;

with 'Email::Footer::RW';

sub can_handle {
  my ($class, $email) = @_;

  return   ref $email eq 'Email::MIME' ? 1
         : ref $email eq 'SCALAR'      ? 1
         :                               0;
}

sub _get_mime_object {
  my ($self, $email) = @_;

  return ref $email eq 'Email::MIME' ? $email : Email::MIME->new($$email);
}

sub _update_input {
  my ($self, $input, $email) = @_;

  if (ref $input eq 'SCALAR') {
    $$input = $email->as_string;
  } else {
    %$input = %$email;
  }

  return;
}

sub walk_parts {
  my ($self, $input, $what, $text_sub, $html_sub) = @_;

  my $email = $self->_get_mime_object($input);

  # Don't strip footers from this type since we found a signed part
  my $dont_strip_text;
  my $dont_strip_html;

  if ($email->content_type =~ m[multipart/signed]i) {
    my ($first) = $email->subparts;

    # Allow signed text or html parts
    my $ct = $first->content_type // 'text/plain';

    if ($what eq 'adding') {
      # Signed message? Upgrade message to multipart/mixed, add a part
      # at the end to put the footer on
      my $converter = Email::Abstract->new($email);
      my $ent = $converter->cast('MIME::Entity');
      $ent->make_multipart('mixed', Force => 1);

      my $foot = MIME::Entity->build(
        Type => $ct,
        Charset => 'UTF-8',
        Data => [ "" ],
      );
      $ent->add_part($foot);

      $converter = Email::Abstract->new($ent);
      $email = $converter->cast('Email::MIME');
    } else {
      # Stripping? We don't want to modify the message
      if ($ct =~ m[text/plain]i) {
        $dont_strip_text = 1;
      } elsif ($ct =~ m[text/html]i) {
        $dont_strip_html = 1;
      }
    }
  }

  # Collect text/html parts
  my @todo = $email;
  my %parts;
  for my $part (@todo) {
    # Don't even think of subparts of signed part
    if ($part->content_type =~ m[multipart/signed]i) {
      next;
    }

    if ($part->subparts) {
      push @todo, $part->subparts;

      next;
    }

    if ($part->content_type =~ m[text/plain]i) {
      my $disp = $part->header('Content-Disposition');

      # Do *not* mess with non-inline attachments
      next if $disp && $disp =~ /attachment/i;

      next if $dont_strip_text || ! $text_sub;

      push @{ $parts{text} }, $part;
    } elsif ($part->content_type =~ m[text/html]i) {
      next if $dont_strip_html || ! $html_sub;

      push @{ $parts{html} }, $part;
    }
  }

  my $last_text_part = @{ $parts{text} }[-1];
  my $last_html_part = @{ $parts{html} }[-1];

  if ($last_text_part) {
    # Ensure an encoding that forces a correct maximum line length
    # incase we rewrite lines to be too long
    my $cte = $last_text_part->header('Content-Transfer-Encoding') // '';
    $last_text_part->encoding_set('quoted-printable')
      unless $cte =~ /\A (?: quoted-printable | base64 ) \z/ix;

    # No charset? Default to us-ascii (perhaps Email::MIME should do this?)
    # This is for input only. We will always write out UTF-8 as our template
    # may contain it
    my $ct = Email::MIME::parse_content_type($last_text_part->content_type);
    unless ($ct->{attributes}{charset}) {
      $last_text_part->charset_set('us-ascii');
    }

    my $body = $last_text_part->body_str;
    $text_sub->(\$body);

    # change to UTF-8
    $last_text_part->charset_set('UTF-8');

    $last_text_part->body_str_set($body);
  }

  if ($last_html_part) {
    # Ensure an encoding that forces a correct maximum line length
    # incase we rewrite lines to be too long
    my $cte = $last_html_part->header('Content-Transfer-Encoding') // '';
    $last_html_part->encoding_set('quoted-printable')
      unless $cte =~ /\A (?: quoted-printable | base64 ) \z/ix;

    # No charset? Default to us-ascii (perhaps Email::MIME should do this?)
    # This is for input only. We will always write out UTF-8 as our template
    # may contain it
    my $ct = Email::MIME::parse_content_type($last_html_part->content_type);
    unless ($ct->{attributes}{charset}) {
      $last_html_part->charset_set('us-ascii');
    }

    my $body = $last_html_part->body_str;
    $html_sub->(\$body);

    # change to UTF-8
    $last_html_part->charset_set('UTF-8');

    $last_html_part->body_str_set($body);
  }

  # Blow away cache or ->as_string will *LIE*. We must refresh multipart
  # parts depth first so wrapping parts get updated information
  my @to_set;

  $email->walk_parts(sub {
    my ($part) = @_;

    if ($part->subparts) {
      push @to_set, $part;
    }
  });

  for my $part (reverse @to_set) {
    $part->parts_set([ $part->subparts ]);
  }

  $self->_update_input($input, $email);

  return;
}

1;

__END__
