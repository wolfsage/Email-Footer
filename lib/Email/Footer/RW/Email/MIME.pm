package Email::Footer::RW::Email::MIME;

use Moose;

use Email::MIME;

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

sub _maybe_update_bare_email {
  my ($self, $input, $email) = @_;

  return unless ref $input eq 'SCALAR';

  $$input = $email->as_string;

  return;
}

sub walk_parts {
  my ($self, $input, $what, $text_sub, $html_sub) = @_;

  my $email = $self->_get_mime_object($input);

  # Find the last text/html parts in the message
  my $last_text_part;
  my $last_html_part;

  # Don't strip footers from this type since we found a signed part
  my $dont_strip_text;
  my $dont_strip_html;

  $email->walk_parts(sub {
    my ($part) = @_;

    if ($part->content_type && $part->content_type =~ m[multipart/signed]i) {
      # Signed message? Add a part to the end that will contain the
      # footer so we don't break signatures
      my ($first) = $part->subparts;

      # Allow signed text or html parts
      my $ct = $first->content_type // 'text/plain';

      if ($what eq 'adding') {
        my $new_part = Email::MIME->create(
          attributes => {
            content_type => $ct,
            charset      => "UTF-8",
            encoding     => "quoted-printable",
          },
          body_str => "",
        );

        $email->parts_add([$new_part]);
      } else {
        # We're in strip mode, don't bother if we have signed parts
        if ($ct =~ m[text/plain]i) {
          $dont_strip_text = 1;
        } elsif ($ct =~ m[text/html]i) {
          $dont_strip_html = 1;
        }
      }
    }

    return if $part->subparts;

    if ($part->content_type =~ m[text/plain]i) {
      return unless $text_sub;

      $last_text_part = $part;
    } elsif ($part->content_type =~ m[text/html]i) {
      return unless $html_sub;

      $last_html_part = $part;
    }
  });

  # Are we in strip mode and we ended up with a signed part
  # matching this content_type?
  if ($dont_strip_text) {
    $last_text_part = undef;
  }

  if ($dont_strip_html) {
    $last_html_part = undef;
  }

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

  $self->_maybe_update_bare_email($input, $email);

  return;
}

1;

__END__
