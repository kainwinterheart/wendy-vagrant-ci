#!/usr/bin/perl

use strict;

use Carp;

package Wendy::Db;

require Exporter;

our @ISA         = qw( Exporter );

our @EXPORT      = qw( dbconnect
		       wdbconnect
		       wdbbegin
		       wdbcommit
		       wdbrollback
		       dbprepare
		       wdbprepare
		       dbdisconnect
		       wdbdisconnect
		       dbquote
		       dbgeterror
		       wdbgeterror
		       wdbdo
		       wtransaction
		       dbselectrow
		       seqnext );

our @EXPORT_OK   = qw( dbconnect
		       wdbconnect
		       __do_connect
		       wdbbegin
		       wdbcommit
		       wdbrollback
		       dbprepare
		       wdbprepare
		       dbdisconnect
		       wdbdisconnect
		       dbquote
		       wdbquote
		       dbgeterror
		       wdbgeterror
		       dbdo
		       wdbdo
		       dbselectrow
		       seqnext
		       wtransaction );

our %EXPORT_TAGS = ( default => [ ] );
our $VERSION     = 1.00;

use Wendy::Config ':dbauth';
use DBI;
use DBD::Pg;
use Carp::Assert;

my $rdbh = undef;
my $wdbh = undef;

my $one_dbh = 0;

sub dbconnect
{
	unless( $rdbh )
	{
		my $rdbhost = CONF_DBHOST;

		if( ref $rdbhost )
		{
rDhHOm41w4tWnBxp:
			foreach my $host ( @$rdbhost )
			{
				if( $rdbh = &__do_connect( $host ) )
				{
					last rDhHOm41w4tWnBxp;
				}
			}
		} else
		{
			$rdbh = &__do_connect( $rdbhost );
		}
	}

	return $rdbh;
}


sub wdbconnect
{
	unless( $wdbh )
	{
		my $wdbhost = CONF_WDBHOST;

		if( $wdbhost )
		{
			if( ref $wdbhost )
			{
				
			      gQUZ58SVNa3exkcY:
				foreach my $host ( @$wdbhost )
				{
					if( $wdbh = &__do_connect( $host ) )
					{
						last gQUZ58SVNa3exkcY;
					}
				}
			} else
			{
				$wdbh = &__do_connect( $wdbhost );
			}
		} else
		{
			$one_dbh = 1;
			$wdbh = $rdbh;
		}
	}

	return $wdbh;
}

sub __do_connect
{
	my $host = shift;

	my $dbh = DBI -> connect( 'dbi:Pg:dbname=' . CONF_DBNAME . ';host=' . $host . ';port=' . CONF_DBPORT,
			          CONF_DBUSER,
				  CONF_DBPASSWORD,
				  {
					  RaiseError => 1
				  } );
	$dbh -> { "pg_server_prepare" } = 0;
	return $dbh;
}

sub wdbbegin
{
	my $rv = 1;

	unless( &in_wtransaction() )
	{
		unless( $wdbh -> begin_work() )
		{
			$rv = undef;
		}
	}

	return $rv;
}

sub wdbcommit
{
	$wdbh -> commit() or return undef;
	return 1;
}

sub wdbrollback
{
	$wdbh -> rollback() or return undef;
	return 1;
}

sub dbprepare
{
	my $sql = shift;

	unless( $rdbh )
	{
		assert( 0, 'rdbh is undefined' );
	}

	my $sth = $rdbh -> prepare( $sql ) or return undef;

	return $sth;
}

sub wdbprepare
{
	my $sql = shift;
	my $sth = $wdbh -> prepare( $sql ) or return undef;

	return $sth;
}

sub dbselectrow
{
	return $rdbh -> selectrow_hashref( shift );
}

sub dbdo
{
	my $sql = shift;
	$rdbh -> do( $sql ) or return undef;

	return 1;
}

sub wdbdo
{
	my $sql = shift;

	assert( $wdbh );


	my $rv = undef;

	eval {

		$rv = $wdbh -> do( $sql );
	};


	if( my $t = $@ )
	{
		assert( 0, sprintf( "(%s) REQ: %s", $t, $sql ) );
	}

	return $rv;
}

sub dbgeterror
{
	return $rdbh -> errstr();
}

sub wdbgeterror
{
	return $wdbh -> errstr();
}

sub dbquote
{
	my $val = shift;

	# if( my $t = ref( $val ) )
	# {
	# 	Carp::cluck( sprintf( "quoting ref to %s with value %s", $t, $val ) );
	# }

	return $rdbh -> quote( $val );
}

sub wdbquote
{
	my $val = shift;
	return $wdbh -> quote( $val );
}

sub dbdisconnect
{
	if( $rdbh )
	{
		$rdbh -> disconnect();
		$rdbh = undef;
	}

	if( $one_dbh )
	{
		$wdbh = undef;
	}
}

sub wdbdisconnect
{
	unless( $one_dbh )
	{
		if( $wdbh )
		{
			$wdbh -> disconnect();
			$wdbh = undef;
		}
	}
}

sub seqnext
{
	my $sname = shift;

	my $sql = sprintf( "SELECT nextval(%s) AS id", &dbquote( $sname ) );
	my $sth = &wdbprepare( $sql );
	$sth -> execute();
	my $data = $sth -> fetchrow_hashref();
	my $rv = $data -> { "id" };
	$sth -> finish();

	return int( $rv );
}

sub dbh_in_transaction
{
	my $dbh = shift;

	my $rv = 0;

	if( $dbh -> { 'AutoCommit' } )
	{
		my $rc = $dbh -> ping();
		
		if( ( $rc == 3 ) or ( $rc == 4 ) )
		{
			$rv = 1;
		}
	} else
	{
		$rv = 1;
	}

	return $rv;
}

sub in_wtransaction
{
	return &dbh_in_transaction( $wdbh );
}

sub wtransaction
{
	my $error = 0;
	my $failed_req = undef;
	my $errmsg = undef;

	&wdbconnect();

	my $already_in_transaction = &in_wtransaction();

	unless( $error )
	{
		unless( $already_in_transaction )
		{
			unless( &wdbbegin() )
			{
				$error = 1;
				$failed_req = 'BEGIN';
				$errmsg = &wdbgeterror();
			}
		}
	}

	unless( $error )
	{
xFPy1bMQuwLVioXa:
		foreach my $req ( @_ )
		{
			unless( &wdbdo( $req ) )
			{
				$error = 1;
				$failed_req = $req;
				$errmsg = &wdbgeterror();
				last xFPy1bMQuwLVioXa;
			}
		}
	}

	if( $error )
	{
		unless( $already_in_transaction )
		{
			&wdbrollback();
		}
	} else
	{
		unless( $already_in_transaction )
		{
			unless( &wdbcommit() )
			{
				$error = 1;
				$failed_req = 'COMMIT';
				$errmsg = &wdbgeterror();
			}
		}
	}

	return { error => $error,
		 req   => $failed_req,
		 msg   => $errmsg };
}

1;
