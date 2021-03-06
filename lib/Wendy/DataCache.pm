#!/usr/bin/perl

use strict;

package Wendy::DataCache;

use Wendy::Config;
use Wendy::Memcached;
use Wendy::Util::File;

use File::Spec;
use Fcntl ':flock';
use Digest::MD5 'md5_hex';

require Exporter;

our @ISA         = qw( Exporter );

our @EXPORT      = qw( datacache_store
		       datacache_retrieve
		       datacache_clear

                       dc_store
                       dc_hit );

our @EXPORT_OK   = @EXPORT;

our $VERSION     = 1.00;

# This module is somewhat affected by race conditions. Use with caution.

use Storable ( 'freeze', 'thaw' );
use Carp::Assert;

sub dc_store
{
	my %args = @_;
	
	my ( $id,
	     $data,
	     $ttl ) = @args{ "Id",
			     "Data",
			     "TTL" };

	my $t = $data;

	unless( ref( $data ) )
	{
		assert( 0, 'only references accepted' );
	}

	return &datacache_store( Id => $id,
				 Data => freeze( $t ),
				 TTL => $ttl );

}

sub dc_hit
{
	my $id = shift;

	my $rv = undef;

	if( my $t = &datacache_retrieve( $id ) )
	{
		$rv = thaw( $t );
	}

	return $rv;
}

sub datacache_store
{
	my %args = @_;
	
	my ( $id,
	     $data,
	     $ttl ) = @args{ "Id",
			     "Data",
			     "TTL" };

	if( CONF_MEMCACHED )
	{
		# Store in memory.
		&mc_set( md5_hex( $id ), $data, $ttl );
	} else
	{
		# Then store in file.
		my $WOBJ = undef;

		eval { $WOBJ = &Wendy::__get_wobj() };

		unless( $WOBJ )
		{
			return undef;
		}
		
		my $cachestore = File::Spec -> catfile( CONF_VARPATH,
							'hosts',
							$WOBJ -> { "HOST" } -> { 'host' },
							'cache',
							'dc_' . md5_hex( $id ) );
		
		my ( $cachedattrsdata, $attrssavepath ) = ( undef, undef );
		{
			my %cacheattrs = ( 'expires' => ( $ttl ? time() + $ttl : '' ) );
			$attrssavepath = $cachestore . '.attrs';

			if( scalar grep { $_ } values %cacheattrs )
			{
				$cachedattrsdata = join( ':::', %cacheattrs );
			}
		}
		
		
		if( $cachedattrsdata )
		{
			unless( &save_data_in_file_atomic( $cachedattrsdata, $attrssavepath ) )
			{
				return 0;
			}
		} else
		{
			unlink( $attrssavepath );
		}

		my $rv = &save_data_in_file_atomic( $data, $cachestore );

	}
						
	return 1;
}

sub datacache_retrieve
{
	my $id = shift;
	my $rv = undef;
	if( CONF_MEMCACHED )
	{
		$rv = &mc_get( md5_hex( $id ) );
	} else
	{
		my $WOBJ = undef;

		eval { $WOBJ = &Wendy::__get_wobj() };

		unless( $WOBJ )
		{
			return undef;
		}

		my $cachestore = File::Spec -> catfile( CONF_VARPATH,
							'hosts',
							$WOBJ -> { "HOST" } -> { 'host' },
							'cache',
							'dc_' . md5_hex( $id ) );

		if( -f $cachestore )
		{
			my $badcache = 0;
			my $cacheattrs_store = $cachestore . '.attrs';
			if( -f $cacheattrs_store )
			{
				my $tfh = undef;

				if( open( $tfh, '<', $cacheattrs_store ) )
				{
					my %attrs = split( /\Q:::\E/, <$tfh> );
					if( $attrs{ 'expires' }
					    and
					    ( $attrs{ 'expires' } < time() ) )
					{
						$badcache = 1;
					}

					close $tfh;
				}
			}
			
			unless( $badcache )
			{
				my $tfh = undef;
				if( open( $tfh, '<', $cachestore ) )
				{
					$rv = join( '', <$tfh> );
					close $tfh;
				}
			}
		}
	}
	return $rv;
}

sub datacache_clear
{
	my $id = shift;

	if( CONF_MEMCACHED )
	{
		&mc_delete( md5_hex( $id ) );
	} else
	{
		my $WOBJ = &Wendy::__get_wobj();

		my $cachestore = File::Spec -> catfile( CONF_VARPATH,
							'hosts',
							$WOBJ -> { "HOST" } -> { 'host' },
							'cache',
							'dc_' . md5_hex( $id ) );

		my $cacheattrs_store = $cachestore . '.attrs';

		map { unlink $_ if -f $_ } ( $cachestore,
					     $cacheattrs_store );

	}
	return 1;
}

1;
