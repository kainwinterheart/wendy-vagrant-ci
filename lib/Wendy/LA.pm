#!/usr/bin/perl

use strict;

package Wendy::LA;
require Exporter;

our @ISA         = qw( Exporter );
our @EXPORT      = qw( getla );
our @EXPORT_OK   = @EXPORT;
our $VERSION     = 1.00;

use Sys::Statistics::Linux::LoadAVG;

sub getla
{
	my $lxs  = Sys::Statistics::Linux::LoadAVG -> new();
	my $stat = $lxs -> get();
	
	return $stat -> { 'avg_1' };

}

sub getdbla
{
	my $dbh = $Wendy::WOBJ{ 'DBH' };
	my $rv = 0;
	if( $dbh )
	{
		my $r = $dbh -> selectrow_hashref( "SELECT perl_getla() AS getla" );
		$rv = $r -> { 'getla' };
	}
	return $rv;
}



1;
