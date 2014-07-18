#!/bin/sh

# -p (default, setting, arg)
# PKGSRC (default, setting)
# BUILDLOG (default, setting)

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
	runScript -abcdefghijklmnopqrstuvwxyz

	checkResults 1 "script exited non-zero" \
		"" "stdout was empty" \
		"^usage: " "stderr was usage"
}

testDashH() {
	runScript -h

	checkResults 0 "script exited true" \
		"" "stdout was empty" \
		"^usage: " "stderr was usage"
}

testDashV() {
	echo "exit 23" > $DEFAULTSCONF
	PS4="UNIQUETESTVALUE " runScript -v

	checkResults 23 "script exited as expected" \
		"" "stdout has no output" \
		"^$PS4" "stderr has verbose output"
}

testConfig() {
	unset CONFIG
	VALUE=$(
		. $DEFAULTSCONF
		echo $CONFIG
	)
	assertEquals "CONFIG has expected hard-coded value" "/etc/ubulk.conf" "$VALUE"

	VALUE=$(
		CONFIG=/etc/fake
		. $DEFAULTSCONF
		echo $CONFIG
	)
	assertEquals "DEFAULTSCONF doesn't override already-set value" "/etc/fake" "$VALUE"

	echo 'CONFIG=./fake.conf' > $DEFAULTSCONF
	echo 'exit 23' > ./fake.conf
	runScript
	checkResults 23 "script is obeying the default CONFIG path, by default" \
		"" "stdout has no output" \
		"" "stderr has no output"

	echo 'exit 24' > ./fake2.conf
	runScript -C ./fake2.conf
	checkResults 24 "script obeys command-arg over hard-coded default" \
		"" "stdout has no output" \
		"" "stderr has no output"
}

testDoPkgChk() {
	unset DOPKGCHK
	VALUE=$(
		. $DEFAULTSCONF
		echo $DOPKGCHK
	)
	assertEquals "DOPKGCHK has expected hard-coded value" "yes" "$VALUE"

	VALUE=$(
		DOPKGCHK=no
		. $DEFAULTSCONF
		echo $DOPKGCHK
	)
	assertEquals "DOPKGCHK doesn't override already-set value" "no" "$VALUE"

	cp $DEFAULTSCONF ${DEFAULTSCONF}.save
	echo >> $DEFAULTSCONF &&  echo "UPDATEPKGSRC=no" >> $DEFAULTSCONF
	echo >> $DEFAULTSCONF && echo "DOPKGCHK=no" >> $DEFAULTSCONF
	runScript
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "script obeyed the hard-coded default" \
		"" "nothing on stderr"

	# use the default defaults file ('yes') (and the default config file)
	cp ${DEFAULTSCONF}.save $DEFAULTSCONF
	# but turn off pkgsrc again
	echo >> $DEFAULTSCONF &&  echo "UPDATEPKGSRC=no" >> $DEFAULTSCONF
	# and turn off DOPKGCHK again in the config file
	echo "DOPKGCHK=no" > ./testubulk.conf
	runScript -C ./testubulk.conf
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "setting trumps hard-coded default" \
		"" "nothing on stderr"

	# this time skip the config file but trump the default from the command line
	runScript -c no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "command-arg trumps hard-coded default" \
		"" "nothing on stderr"

	# now trump the config file from the command line
	runScript -C ./testubulk.conf -c no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "command-arg trumps config file" \
		"" "nothing on stderr"
}

	# default looks for correct value
		# source defaults.conf ourselves
		# check for correct value
		# check that value doesn't overwrite already-set value
		# write fake defaults.conf
		# check that script obeys the fake defaults.conf
	# setting overrides default
	# command-arg overrides default
	# command-arg overrides setting
#-------------------------------------------------------------------------

runScript() {
	./$SCRIPTNAME "$@" >$OUT 2>$ERR
	RTRN=$?
}

checkResults() {
	local - && set -v
	E_EXIT=$1
	EXIT_MSG="$2"
	E_OUT="$3"
	OUT_MSG="$4"
	E_ERR="$5"
	ERR_MSG="$6"

	if [ $E_EXIT -eq 0 ]; then
		assertTrue "$EXIT_MSG" $RTRN || echo "($RTRN)"
	else
		assertFalse "$EXIT_MSG" $RTRN || echo "($RTRN)"
	fi

	if [ "" = "$E_OUT" ]; then
		assertNull "$OUT_MSG" "$(cat $OUT)" || cat $OUT
	else
		echo "$(cat $OUT)" | grep "$E_OUT" >/dev/null 2>&1
		assertTrue "$OUT_MSG" $? || cat $OUT
	fi

	if [ "" = "$E_ERR" ]; then
		assertNull "$ERR_MSG" "$(cat $ERR)" || cat $ERR
	else
		echo "$(cat $ERR)" | grep "$E_ERR" >/dev/null 2>&1
		assertTrue "$ERR_MSG" $? || cat $ERR
	fi
}

. ./shunit2
