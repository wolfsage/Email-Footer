package Email::Footer::Renderer;
use Moose::Role;

with 'Email::Footer::Component';

requires 'render';

no Moose::Role;
1;

__END__
