package Email::Footer::RW;

use Moose::Role;

with 'Email::Footer::Component';

requires 'can_handle';

requires 'walk_parts';

no Moose::Role;
1;

__END__
