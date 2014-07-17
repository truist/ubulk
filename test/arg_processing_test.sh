#!/bin/sh

# -C (default, arg)
# -c (default, setting, arg)
# -p (default, setting, arg)
# -v (how?)

. ./common.sh

oneTimeSetUp() {
	OUT=$SHUNIT_TMPDIR/stdout
	ERR=$SHUNIT_TMPDIR/stderr
}

setUp() {
	local - && set -e

	cp ../$SCRIPTNAME $SHUNIT_TMPDIR/
	mkdir $SHUNIT_TMPDIR/lib
	cp ../lib/* $SHUNIT_TMPDIR/lib/

	INITDIR=`pwd`
	cd $SHUNIT_TMPDIR
}

tearDown() {
	local - && set -e

	cd $INITDIR
	rm -rf $SHUNIT_TMPDIR/*
}

#-------------------------------------------------------------------------

testUnknownArg() {
	runScript '-abcdefghijklmnopqrstuvwxyz'

	checkResults 1 \
		"" "stdout was empty" \
		"^usage: " "stderr was usage"
}

testDashH() {
	runScript '-h'

	checkResults 0 \
		"" "stdout was empty" \
		"^usage: " "stderr was usage"
}

#-------------------------------------------------------------------------

runScript() {
	./$SCRIPTNAME "$@" >$OUT 2>$ERR
	RTRN=$?
}

checkResults() {
	local - && set -v
	E_EXIT=$1
	E_OUT="$2"
	OUT_MSG="$3"
	E_ERR="$4"
	ERR_MSG="$5"

	if [ $E_EXIT -eq 0 ]; then
		assertTrue "script exited 0" $RTRN
	else
		assertFalse "script exited non-zero" $RTRN
	fi

	if [ "" = "$E_OUT" ]; then
		assertNull "$OUT_MSG" "$(cat $OUT)"
	else
		echo "$(cat $OUT)" | grep "$E_OUT" >/dev/null 2>&1
		assertTrue "$OUT_MSG" $?
	fi

	if [ "" = "$E_ERR" ]; then
		assertNull "$ERR_MSG" "$(cat $ERR)"
	else
		echo "$(cat $ERR)" | grep "$E_ERR" >/dev/null 2>&1
		assertTrue "$ERR_MSG" $?
	fi
}

. ./shunit2
