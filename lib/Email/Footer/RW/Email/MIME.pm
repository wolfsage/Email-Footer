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

      my $body = $part->body;
      $text_sub->(\$body);
      $part->body_set($body);
    } elsif ($part->content_type =~ m[text/html]i) {
      return unless $html_sub;

      # Ensure an encoding that forces a correct maximum line length
      # incase we rewrite longs to be too long
      my $cte = $part->header('Content-Transfer-Encoding') // '';
      $part->encoding_set('quoted-printable')
        unless $cte =~ /\A (?: quoted-printable | base64 ) \z/ix;

      my $body = $part->body;
      $html_sub->(\$body);
      $part->body_set($body);
    }
  });

  $self->_maybe_update_bare_email($input, $email);

  return;
}

1;

__END__
