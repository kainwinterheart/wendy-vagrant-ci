use strict;
use warnings;

package localhost::root;

use Moose;

extends 'MyService::App';

no Moose;

sub wendy_handler
{
	return __PACKAGE__ -> new() -> run();
}

-1;

