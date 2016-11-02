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
  my ($self, $input, $text_sub, $html_sub) = @_;

  my $email = $self->_get_mime_object($input);

  $email->walk_parts(sub {
    my ($part) = @_;
    return if $part->subparts; # multipart

    if ($part->content_type =~ m[text/plain]i) {
      return unless $text_sub;

      # Ensure an encoding that forces a correct maximum line length
      # incase we rewrite lines to be too long
      my $cte = $part->header('Content-Transfer-Encoding') // '';
      $part->encoding_set('quoted-printable')
        unless $cte =~ /\A (?: quoted-printable | base64 ) \z/ix;

      # Probably shouldn't happen but let's be sure
      unless ($part->content_type) {
        $part->content_type_set('text/plain');
      }

      # No charset? Default to us-ascii (perhaps Email::MIME should do this?)
      # This is for input only. We will always write out UTF-8 as our template
      # may contain it
      my $ct = Email::MIME::parse_content_type($part->content_type);
      unless ($ct->{attributes}{charset}) {
        $part->charset_set('us-ascii');
      }

      my $body = $part->body_str;
      $text_sub->(\$body);

      # change to UTF-8
      $part->charset_set('UTF-8');

      $part->body_str_set($body);
    } elsif ($part->content_type =~ m[text/html]i) {
      return unless $html_sub;

      # Ensure an encoding that forces a correct maximum line length
      # incase we rewrite lines to be too long
      my $cte = $part->header('Content-Transfer-Encoding') // '';
      $part->encoding_set('quoted-printable')
        unless $cte =~ /\A (?: quoted-printable | base64 ) \z/ix;

      # No charset? Default to us-ascii (perhaps Email::MIME should do this?)
      # This is for input only. We will always write out UTF-8 as our template
      # may contain it
      my $ct = Email::MIME::parse_content_type($part->content_type);
      unless ($ct->{attributes}{charset}) {
        $part->charset_set('us-ascii');
      }

      my $body = $part->body_str;
      $html_sub->(\$body);

      # change to UTF-8
      $part->charset_set('UTF-8');

      $part->body_str_set($body);
    }
  });

  $self->_maybe_update_bare_email($input, $email);

  return;
}

1;

__END__
