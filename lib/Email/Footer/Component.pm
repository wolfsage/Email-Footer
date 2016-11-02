package Email::Footer::Component;

use Moose::Role;

has footer => (
  is       => 'ro',
  isa      => 'Email::Footer',
  required => 1,
  weak_ref => 1,
);

no Moose::Role;
1;

__END__
