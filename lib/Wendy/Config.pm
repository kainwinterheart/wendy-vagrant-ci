#!/usr/bin/perl

use strict;

package Wendy::Config;

require Exporter;

use File::Spec;

use constant {

	CONF_DBNAME     => 'wedb',
	CONF_DBUSER     => 'postgres',
	CONF_DBPORT     => 5432,
	CONF_DBHOST     => '127.0.0.1', # or array reference: [ 'localhost', 'otherhost' ]
	CONF_DBPASSWORD => 'drowssap',

	CONF_WDBHOST    => undef,       # if you want to read from one hosts, and write to another
	                                # may specify array reference: [ 'localhost', 'otherhost' ]
                                        # otherwise set to undef

	CONF_DEFHOST    => 'localhost',
	CONF_MYPATH     => '/www/wendy_engine',
	CONF_VARPATH    => File::Spec -> catdir( '/www/wendy_engine', 'var' ),

	CONF_MEMCACHED  => 0,
	CONF_MC_SERVERS => [ '127.0.0.1:11211' ], # may put here several records
	CONF_MC_THRHOLD => 10000,
	CONF_MC_NORHASH => 0,

	CONF_NOCACHE    => 0
};

our $WENDY_VERSION     = '0.9.20080804';

our @ISA         = qw( Exporter );
our @EXPORT      = qw( CONF_DEFHOST
		       CONF_MYPATH
		       CONF_VARPATH
		       CONF_NOCACHE
		       $WENDY_VERSION
		       CONF_MEMCACHED );
our @EXPORT_OK   = qw( CONF_VARPATH
		       CONF_MYPATH
		       CONF_DEFHOST
		       CONF_DBNAME
		       CONF_DBUSER
		       CONF_DBPORT
		       CONF_DBHOST
		       CONF_WDBHOST
		       CONF_DBPASSWORD
		       CONF_NOCACHE
		       $WENDY_VERSION
		       CONF_MEMCACHED
		       CONF_MC_SERVERS
		       CONF_MC_THRHOLD
		       CONF_MC_NORHASH );
our %EXPORT_TAGS = ( dbauth => [
				qw( 
				    CONF_DBNAME
				    CONF_DBUSER
				    CONF_DBPORT
				    CONF_DBHOST
				    CONF_WDBHOST
				    CONF_DBPASSWORD
				    )
				],
		     memcached => [
				   qw(
				      CONF_MEMCACHED
				      CONF_MC_SERVERS
				      CONF_MC_THRHOLD
				      CONF_MC_NORHASH 
				      )
				   ]);


################################################################################


1;
