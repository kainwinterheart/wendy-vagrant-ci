#!/bin/sh

export PERL5LIB="/home/vagrant/perl5/lib/perl5:$PERL5LIB"
export APACHE_TEST_HTTPD="/usr/sbin/apache2"
export APACHE_TEST_APXS="/usr/bin/apxs2"

ADMIN_DBNAME="template1"
USER_DBNAME="wedb"

UNLINK='unlink'
RMRF="rm -rf"
MKDIR="mkdir"
LNS="ln -s"
CPR="cp -r"
CD="cd"
CAT="cat"

PSQL="psql"
PSQLARGS_COMMON="-h localhost -p 5432"
PSQLARGS_ADMIN="${COMMON} -U postgres ${ADMIN_DBNAME}"
PSQLARGS_USER="${COMMON} -U postgres ${USER_DBNAME}"
PSQLARGS_EXEC="-c"

CPANM_INSTALL_DEPS="cpanm -q --installdeps --notest ."
PERL="/usr/bin/perl"
BUILD_PL="./Build.PL"
BUILD="./Build"

TEST_RUNNER="t/TEST"

START_HTTPD="${TEST_RUNNER} -start-httpd"
STOP_HTTPD="${TEST_RUNNER} -stop-httpd"

RUN_TESTS="${TEST_RUNNER} -run-tests"

WWW='/www'
WWW_MODULES="${WWW}/modules"
WWW_WENDY_ENGINE="${WWW}/wendy_engine"
WWW_WENDY_ENGINE_VAR="${WWW_WENDY_ENGINE}/var"

SRC="/vagrant"
SRC_VAR="${SRC}/var"
SRC_VAR_WENDY="${SRC_VAR}/wendy"
SRC_LIB="${SRC}/lib"

TMP="/tmp"

SRC_PROJECT="${SRC}/project"
DST_PROJECT="${TMP}/projectclone"

SRC_OPT="${SRC}/opt"
SRC_PROJECT_OPT="${SRC_PROJECT}/opt"

DST_ERRORLOG="${DST_PROJECT}/t/logs/error_log"


if [ -d $WWW ]; then
	if [ -L $WWW_MODULES ]; then
		$UNLINK $WWW_MODULES
	fi

	if [ -d $WWW_WENDY_ENGINE ]; then
		if [ -L $WWW_WENDY_ENGINE_VAR ]; then
			$UNLINK $WWW_WENDY_ENGINE_VAR
		fi
	fi

	$RMRF $WWW
fi

if [ ! -e $TMP ]; then
	$MKDIR $TMP
fi

if [ -d $DST_PROJECT ]; then
	$RMRF $DST_PROJECT
fi


$PSQL $PSQLARGS_ADMIN $PSQLARGS_EXEC "drop database ${USER_DBNAME}" ;

$PSQL $PSQLARGS_ADMIN $PSQLARGS_EXEC "create database ${USER_DBNAME}" ;

$PSQL $PSQLARGS_USER $PSQLARGS_EXEC "\\i ${SRC_OPT}/wendyinit.sql" ;

$PSQL $PSQLARGS_USER $PSQLARGS_EXEC "\\i ${SRC_OPT}/env.sql" ;

$PSQL $PSQLARGS_USER $PSQLARGS_EXEC "\\i ${SRC_PROJECT_OPT}/db.sql" ;


$MKDIR $WWW &&

$LNS $SRC_LIB $WWW_MODULES &&

$MKDIR $WWW_WENDY_ENGINE &&

$LNS $SRC_VAR_WENDY $WWW_WENDY_ENGINE_VAR &&

$CPR $SRC_PROJECT $DST_PROJECT &&

$CD $DST_PROJECT &&

$CPANM_INSTALL_DEPS &&

$PERL $BUILD_PL &&

$BUILD &&

$START_HTTPD


START_HTTPD_EXITCODE=$?
RUN_TESTS_EXITCODE=2 # some default value


if [ $START_HTTPD_EXITCODE -eq 0 ]; then
	$RUN_TESTS

	RUN_TESTS_EXITCODE=$?

	$STOP_HTTPD
fi

if [ $RUN_TESTS_EXITCODE -ne 0 ]; then
	echo ""
	echo "${DST_ERRORLOG}:"
	$CAT $DST_ERRORLOG
fi


exit $RUN_TESTS_EXITCODE

