use strict;
use warnings;

use Apache::Test '-withtestmore'; # the testing framework
# use Apache::TestUtil; # utility functions
use Apache::TestRequest 'GET_BODY'; # requests' sender

plan tests => 2;

ok( 1, 'the test has been started' );

my $response_content = GET_BODY '/';

is( $response_content, 'Woot!', 'response content is expected' );

exit 0;

