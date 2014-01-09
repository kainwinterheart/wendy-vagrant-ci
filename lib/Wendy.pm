#!/usr/bin/perl

package Wendy;

use strict;
use warnings;

use File::Spec;
use Wendy::Config;

use lib File::Spec -> catdir( CONF_MYPATH, 'lib' );

use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Connection;
use Apache2::RequestUtil;

use Apache2::Access;

use Wendy::Templates;
use Wendy::Hosts;
use Wendy::Db;
use Wendy::LA;

use CGI;
use CGI::Cookie;

use Digest::MD5 'md5_hex';
use Fcntl ':flock';

our %WOBJ = ();

sub __get_wobj
{
	return \%WOBJ;
}

sub handler 
{
	my $r = shift;

	my ( $code, $msg, $ctype, $charset ) = ( 200, 'okay', 'text/html', 'utf-8' );

	my $FILE_TO_SEND = "";
	my $FILE_OFFSET = undef;
	my $FILE_LENGTH = undef;

	my $DATA_TO_SEND = "";
	my @HEADERS_TO_SEND = ();

	my %COOKIES = fetch CGI::Cookie;
	my $PROCRV = {};

	my $CACHEPATH = "";
	my $CACHESTORE = "";
	my $CACHEHIT = 0;
	my $NOCACHE  = CONF_NOCACHE;
	my $CUSTOMCACHE = 0;

	my $LANGUAGE = "";

	my $HANDLERPATH = $ENV{ 'SCRIPT_NAME' } . ( $ENV{ 'PATH_INFO' } or "" ); # just to absorb undef warning
	$HANDLERPATH = ( &form_address( $HANDLERPATH ) or 'root' );


	if( $ENV{ "REQUEST_METHOD" } eq "GET" )
	{
		# quick check cache hit first
		if( $COOKIES{ 'lng' } )
		{
			$LANGUAGE = $COOKIES{ 'lng' } -> value();
		}

		unless( $LANGUAGE )
		{
			if( $ENV{ 'QUERY_STRING' } =~ /lng=(\w+)/i )
			{
				$LANGUAGE = $1;
			}
		}

		if( $LANGUAGE )
		{
			my $params_str = $ENV{ 'QUERY_STRING' };

			$CACHEPATH = $HANDLERPATH . md5_hex( $params_str ) . $LANGUAGE;

			if( $ENV{ 'HTTP_HTTPS' } or $ENV{ 'HTTPS' } )
			{
				$CACHEPATH .= '_S';
			}

			{
				$CACHESTORE = File::Spec -> catdir( CONF_VARPATH, 'hosts', $ENV{ "HTTP_HOST" }, 'cache' );
				$CACHEPATH = File::Spec -> catfile( $CACHESTORE, $CACHEPATH );

				if( ( -f $CACHEPATH ) and ( -s $CACHEPATH ) )
				{
					$FILE_TO_SEND = $CACHEPATH;
					$CACHEHIT = 1;

					my $CCFILE = $CACHEPATH . ".custom";

					if( -f $CCFILE )
					{
						my $cfh = undef;
						my %procrv = ();
						
						if( open( $cfh, "<", $CCFILE ) )
						{
							%procrv = split( /\Q:::\E/, <$cfh> );
							close $cfh;
						}

						$PROCRV = \%procrv;
						
						if( $PROCRV -> { "expires" }
						    and
						    ( $PROCRV -> { "expires" } < time() ) )
						{
							# this cache is expired, do not use it!
							
							if( &getla() < 5.2 )
							{

								if( unlink( $CACHEPATH ) )
								{
									unlink $CACHEPATH . ".custom";
									unlink $CACHEPATH . ".headers";
								}
							
								$FILE_TO_SEND = undef;
								$CACHEHIT = 0;
								goto NOQUICKCACHE;
							}
						}
					}

					$CCFILE = $CACHEPATH . ".headers";
					
					if( -f $CCFILE )
					{
						my $cfh;
						my @cheaders = ();
						
						if( open( $cfh, "<", $CCFILE ) )
						{
							@cheaders = split( /\Q:::\E/, <$cfh> );
							close $cfh;
						}
					
						$PROCRV -> { "headers" } = \@cheaders;
						
					}

					goto PROCRV;
				} else
				{
					$LANGUAGE = '';
					$CACHESTORE = '';
					$CACHEPATH = '';
				}
			}
		}
	}
NOQUICKCACHE:
	

	&dbconnect();

	my %HTTP_HOST = &http_host_init( lc $ENV{ "HTTP_HOST" } );
	my %LANGUAGES = &get_host_languages( $HTTP_HOST{ "id" } );
	my %R_LANGUAGES = reverse %LANGUAGES;



	my $CCHEADERS = 0;
	
		{
			my $t = CGI -> new();
			$WOBJ{ 'CGI' } = $t;
		}


	if( scalar keys %LANGUAGES > 1 )
	{
		if( $ENV{ 'QUERY_STRING' } =~ /lng=(\w+)/i )
		{
			$LANGUAGE = $1;
		}
		
		unless( $LANGUAGE )
		{
			if( $COOKIES{ 'lng' } )
			{
				$LANGUAGE = $COOKIES{ 'lng' } -> value();
			}
		}

		unless( $LANGUAGE )
		{
			if( my $t = $WOBJ{ 'CGI' } -> param( 'lng' ) )
			{
				$LANGUAGE = $t;
			}
		}

		unless( $LANGUAGE )
		{
			if( $ENV{ 'HTTP_ACCEPT_LANGUAGE' } )
			{
				my %HAL = &parse_http_accept_language( $ENV{ 'HTTP_ACCEPT_LANGUAGE' } );
				my $most_wanted_lng = undef;
CETi8lj7Oz:
				foreach my $lng ( sort { $HAL{ $b } <=> $HAL{ $a } } keys %HAL )
				{

					unless( $most_wanted_lng )
					{
						$most_wanted_lng = $lng;
					}

					if( exists $R_LANGUAGES{ $lng } )
					{
						$LANGUAGE = $lng;
						last CETi8lj7Oz;
					}
				}

				unless( $LANGUAGE )
				{
					# we have accept-language header
					# but still no suitable languages 
					# were matched


					my %map = ( uk => 'ru',
						    be => 'ru',
						    lt => 'ru',
						    lv => 'ru',
						    et => 'ru',
						    kk => 'ru',
						    zh => 'cn',

						    fr => 'en',
						    de => 'en',
						    ja => 'en',
						    es => 'en',


						    hy => 'ru' );

					$LANGUAGE = ( $map{ $most_wanted_lng } or 'en' );

				}


			}
		}

		$CCHEADERS = 1;
	} # if more than 1 language for host, try to somehow determine most apropriate

	unless( $R_LANGUAGES{ $LANGUAGE } )
	{
		$LANGUAGE = $LANGUAGES{ $HTTP_HOST{ 'defaultlng' } };
	}

	if( $CCHEADERS )
	{
		my $lngcookie = new CGI::Cookie( -name  => 'lng',
						 -value => $LANGUAGE );

		push @HEADERS_TO_SEND, { 'Set-Cookie' => $lngcookie -> as_string() };
	}

	my $FILENAME = File::Spec -> canonpath( File::Spec -> catfile( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'htdocs', $ENV{ "SCRIPT_NAME" }, $ENV{ 'PATH_INFO' } ) );

	if( -d $FILENAME )
	{
		1;
	} elsif( -f $FILENAME )
	{

		$code = 400;
		$msg = 'static is not served';
		$ctype = 'text/plain';
		$charset = undef;
		$DATA_TO_SEND = $msg;
		$NOCACHE = 1;

		goto WORKOUTPUT;

	}else
	{
		$code = 302;
		$msg = "404 not found";
		$ctype = 'text/plain';
		$charset = undef;
		$DATA_TO_SEND = $msg;
		push @HEADERS_TO_SEND, { Location => '/404/' };

		$NOCACHE = 1;

		goto WORKOUTPUT;
	}

	if( $ENV{ "REQUEST_METHOD" } eq "GET" ) # cache it
	{
		my $params_str = $ENV{ 'QUERY_STRING' };
		$CACHEPATH = $HANDLERPATH . md5_hex( $params_str ) . $LANGUAGE;

		if( $ENV{ 'HTTP_HTTPS' } or $ENV{ 'HTTPS' } )
		{
			$CACHEPATH .= '_S';
		}
	}

	if( $CACHEPATH )
	{
		$CACHESTORE = File::Spec -> catdir( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'cache' );
		$CACHEPATH = File::Spec -> catfile( $CACHESTORE, $CACHEPATH );

		if( ( -f $CACHEPATH ) and ( -s $CACHEPATH ) )
		{
			$FILE_TO_SEND = $CACHEPATH;
			$CACHEHIT = 1;

			my $CCFILE = $CACHEPATH . ".custom";

			if( -f $CCFILE )
			{
				my $cfh = undef;
				my %procrv = ();

				if( open( $cfh, "<", $CCFILE ) )
				{
					%procrv = split( /\Q:::\E/, <$cfh> );
					close $cfh;
				}

				$PROCRV = \%procrv;

				if( $PROCRV -> { "expires" }
				    and
				    ( $PROCRV -> { "expires" } < time() ) )
				{
					# this cache is expired, do not use it!
					if( ( &getla() < 5.2 ) and ( &Wendy::LA::getdbla() < 3.0 ) )
					{
						unlink $CACHEPATH;
						unlink $CACHEPATH . ".headers";
						unlink $CACHEPATH . ".custom";
						
						$FILE_TO_SEND = undef;
						$CACHEHIT = 0;
						goto CACHEDONE;
					}
				}
			}

			$CCFILE = $CACHEPATH . ".headers";

			if( -f $CCFILE )
			{
				my $cfh;
				my @cheaders = ();

				if( open( $cfh, "<", $CCFILE ) )
				{
					@cheaders = split( /\Q:::\E/, <$cfh> );
					close $cfh;
				}

				$PROCRV -> { "headers" } = \@cheaders;

			}
			goto PROCRV;
		}
	}
CACHEDONE:

	my $TPLSTORE = File::Spec -> catdir( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'tpl'  );
	my $HOSTLIBSTORE = File::Spec -> catdir( CONF_VARPATH, 'hosts', $HTTP_HOST{ "host" }, 'lib' );
	my $PATHHANDLERSRC = File::Spec -> catfile( $HOSTLIBSTORE, $HANDLERPATH . ".pl" );
	my $METAHANDLERSRC = File::Spec -> catfile( $HOSTLIBSTORE, "meta.pl" );

	%WOBJ = ( %WOBJ,
		  COOKIES    => \%COOKIES,
		  REQREC     => $r,
		  DBH        => &dbconnect(),
		  HOST       => \%HTTP_HOST,
		  LNG        => $LANGUAGE,
		  RLNGS      => \%R_LANGUAGES,
		  TPLSTORE   => $TPLSTORE,
		  HPATH      => $HANDLERPATH,
		  HANDLERSRC => $PATHHANDLERSRC );
	
	&unset_macros();

	my $handler_called = 0;

	if( -f $PATHHANDLERSRC )
	{

		no strict "refs";

		my $full_handler_name = join( '::', ( &form_address( $HTTP_HOST{ 'host' } ),
						      $HANDLERPATH,
						      'wendy_handler' ) );

		if( exists &{ $full_handler_name } )
		{
			$PROCRV = &{ $full_handler_name }( \%WOBJ );
			$handler_called = 1;
		} else
		{
			require $PATHHANDLERSRC;

			if( exists &{ $full_handler_name } )
			{
				$PROCRV = &{ $full_handler_name }( \%WOBJ );
				$handler_called = 1;
			}
		}

		if( $handler_called )
		{
			unless( ref( $PROCRV ) )
			{
				my $t_procrv = { 'data' => $PROCRV };
				$PROCRV = $t_procrv;
			}
		}

	} elsif( -f $METAHANDLERSRC )
	{

		{
			my $t = new CGI;
			$WOBJ{ 'CGI' } = $t;
		}

		no strict "refs";

		my $full_handler_name = join( '::', ( &form_address( $HTTP_HOST{ 'host' } ),
						      'meta',
						      'wendy_handler' ) );

		if( exists &{ $full_handler_name } )
		{
			$PROCRV = &{ $full_handler_name }( \%WOBJ );
			$handler_called = 1;

		} else
		{
			require $METAHANDLERSRC;
			$PROCRV = &{ $full_handler_name }( \%WOBJ );
			$handler_called = 1;
		}

		if( $handler_called )
		{
			unless( ref( $PROCRV ) )
			{
				my $t_procrv = { 'data' => $PROCRV };
				$PROCRV = $t_procrv;
			}
		}
	}

	unless( $handler_called )
	{

		{
			my $t = new CGI;
			$WOBJ{ 'CGI' } = $t;
		}


		&sload_macros( 'ANY' );
		&sload_macros();
		$PROCRV = &template_process();
	}

PROCRV:
	if( $PROCRV -> { "rawmode" } )
	{
		goto WORKFINISHED;
	}

	if( $PROCRV -> { "ctype" } )
	{
		$CUSTOMCACHE = 1;
		$ctype = $PROCRV -> { "ctype" };
	}

	if( $PROCRV -> { "charset" } )
	{
		$CUSTOMCACHE = 1;
		$charset = $PROCRV -> { "charset" };
	}
	
	if( $PROCRV -> { "msg" } )
	{
		$CUSTOMCACHE = 1;
		$msg = $PROCRV -> { "msg" };
	}

	if( $PROCRV -> { "code" } )
	{
		$CUSTOMCACHE = 1;
		$code = $PROCRV -> { "code" };
	}
	
	if( defined $PROCRV -> { "data" } )
	{
		$DATA_TO_SEND = $PROCRV -> { "data" };
	}
	
	if( $PROCRV -> { "file" } )
	{
		$FILE_TO_SEND = $PROCRV -> { "file" };

		if( $PROCRV -> { "file_offset" } )
		{
			$FILE_OFFSET = $PROCRV -> { "file_offset" };
		}
		
		if( $PROCRV -> { "file_length" } )
		{
			$FILE_LENGTH = $PROCRV -> { "file_length" };
		}
	}

	if( ref( $PROCRV -> { "headers" } ) )
	{
		$CCHEADERS = 1;

		if( ref( $PROCRV -> { "headers" } ) eq 'HASH' )
		{
			foreach my $header ( keys %{ $PROCRV -> { "headers" } } )
			{
				push @HEADERS_TO_SEND, { $header => $PROCRV -> { "headers" } -> { $header } };
			}
		} elsif( ref( $PROCRV -> { "headers" } ) eq 'ARRAY' )
		{
			my @t = @{ $PROCRV -> { "headers" } };
			while ( my $key = shift @t )
			{
				my $value = shift @t;
				push @HEADERS_TO_SEND, { $key => $value };
			}
		}
	}

	if( $PROCRV -> { "nocache" } )
	{
		$NOCACHE = 1;
	}

	if( defined $PROCRV -> { "ttl" } )
	{
		$PROCRV -> { "expires" } = time() + $PROCRV -> { "ttl" };
		delete $PROCRV -> { "ttl" };
	}

	if( $PROCRV -> { "expires" } )
	{
		$CUSTOMCACHE = 1;
	}


WORKOUTPUT:
	if( ( $CACHEHIT == 0 ) and ( $NOCACHE == 0 ) and $CACHEPATH )
	{
		
		if( $CCHEADERS )
		{
			my $CCFILE = $CACHEPATH . ".headers";
			my $cfh = undef;
			
			if( open( $cfh, '>', $CCFILE ) )
			{
				my $flock_result = flock( $cfh, LOCK_EX | LOCK_NB );
				if( $flock_result )
				{
					print $cfh join( ':::', map { join( ":::", ( %$_ ) ) } @HEADERS_TO_SEND );
				} else
				{
					$NOCACHE = 1;
				}
				close $cfh;
			} else
			{
				
				die 'cant store headers: ' . $CCFILE . ' - ' . $!;
			}

			delete $PROCRV -> { "headers" };
		}
		
		if( $CUSTOMCACHE )
		{
			my $CCFILE = $CACHEPATH . ".custom";
			my $cfh = undef;
			
			delete $PROCRV -> { "data" };

			if( open( $cfh, '>', $CCFILE ) )
			{
				my $flock_result = flock( $cfh, LOCK_EX | LOCK_NB );
				if( $flock_result )
				{
					print $cfh join( ':::', %$PROCRV );
				} else
				{
					$NOCACHE = 1;
				}
				close $cfh;
			} else
			{
				die 'cant store custom cache attrs: ' . $!;
			}
		}
		
		unless( $NOCACHE )
		{
			
			my $cfh = undef;
			open( $cfh, '>', $CACHEPATH ) or die 'cant store cache ' . $CACHEPATH . $!;

			my $flock_result = flock( $cfh, LOCK_EX | LOCK_NB );
			if( $flock_result )
			{
				print $cfh $DATA_TO_SEND;
			}
			close $cfh;
		}


	}

	$r -> status( $code );
	$r -> status_line( join( ' ', ( $code, $msg ) ) );

	if( $ctype )
	{
		$r -> content_type( $ctype . ( $charset ? '; charset=' . $charset : '' ) );
	}

	if( scalar @HEADERS_TO_SEND )
	{
		foreach my $header ( @HEADERS_TO_SEND )
		{
			my ( $key, $value ) = %$header;
			$r -> headers_out() -> add( $key => $value );
		}
	}

	unless( $r -> header_only() )
	{
		if( $FILE_TO_SEND )
		{
			$r -> sendfile( $FILE_TO_SEND, $FILE_OFFSET, $FILE_LENGTH );
		}
		
		if( defined $DATA_TO_SEND )
		{
			$r -> print( $DATA_TO_SEND );
		}
	}

WORKFINISHED:
	&dbdisconnect();
	&wdbdisconnect();

	%WOBJ = ();

	return;
}

sub parse_http_accept_language
{
	my $alstr = shift;
	$alstr =~ s/\s//g;
	my @lq = split ",", $alstr;
	my %outcome = ();

	my $curq = 1;

	foreach ( @lq )
	{
		my ( $lng, $q ) = split ";q=", $_;
		unless( $q )
		{
			$q = $curq;
			$curq -= 0.1;
		}

		my ( $lng_code, $country_code ) = split( /-/, $lng, 2 );
		$lng = $lng_code;

		$outcome{ $lng } = $q;
	}
	return %outcome;
}

1;
