#!/usr/bin/perl

use Apache::TestMB ();

Apache::TestMB
	-> new(
		module_name => 'MyService',
                dist_abstract => 'My cool service',
                dist_author => [ 'Someone <test@example.com>' ],
                recursive_test_files => 1,
		license => 'perl',
		build_requires     => {
			'Apache::Test' => '>= 1.31'
		},
		requires => {
			perl => '>= 5.10.1',
			'Apache2::Access' => 0,
			'Apache2::Connection' => 0,
			'Apache2::Const' => 0,
			'Apache2::RequestIO' => 0,
			'Apache2::RequestRec' => 0,
			'Apache2::RequestUtil' => 0,
			'Apache::DBI' => 0,
			'Cache::Memcached' => 0,
			'Carp::Assert' => 0,
			'CGI' => 0,
			'CGI::Cookie' => 0,
			'Crypt::SSLeay' => 0,
			'Cwd' => 0,
			'Data::Dumper' => 0,
			'Data::Validate::URI' => 0,
			'DateTime' => 0,
			'DBD::Pg' => 0,
			'DBI' => 0,
			'Digest::MD5' => 0,
			'Fcntl' => 0,
			'File::Basename' => 0,
			'File::Copy' => 0,
			'File::Path' => 0,
			'File::Spec' => 0,
			'File::Temp' => 0,
			'File::Touch' => 0,
			'File::Util' => 0,
			'HTTP::Headers' => 0,
			'HTTP::Request::Common' => 0,
			'LWP::UserAgent' => 0,
			'MIME::Base64' => 0,
			'MIME::Lite' => 0,
			'MIME::Types' => 0,
			'Moose' => 0,
			'Storable' => 0,
			'String::ShellQuote' => 0,
			'Sys::Statistics::Linux::LoadAVG' => 0,
			'Template' => 0,
			'Term::ReadLine' => 0,
			'TryCatch' => 0,
			'URI' => 0,
			'XML::Quote' => 0,
		}
	)
	-> create_build_script()
;

exit 0;

