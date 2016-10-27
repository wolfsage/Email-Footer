package Email::Footer::Renderer::Text::Template;
use Moose;

use Text::Template qw(fill_in_string);

with 'Email::Footer::Renderer';

sub render {
  my ($self, $template, $arg) = @_;

  my $result = fill_in_string(
    $template,
    HASH   => $arg,
    BROKEN => sub { my %hash = @_; die $hash{error}; },
  );

  die $Text::Template::ERROR unless defined $result;

  return $result;
}

1;
