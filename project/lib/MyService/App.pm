use strict;
use warnings;

package MyService::App;

use Moose;

extends 'Wendy::App';

sub app_mode_default
{
	my $self = shift;

	return $self -> nctd( 'Woot!' );
}

no Moose;

-1;

