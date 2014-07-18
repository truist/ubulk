#!/bin/sh

. ./common.sh

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
	checkDefaultsFile "CONFIG" "/etc/ubulk.conf" "/etc/fake"

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
	checkDefaultsFile "DOPKGCHK" "yes" "no"

	cp $DEFAULTSCONF ${DEFAULTSCONF}.save
	echo >> $DEFAULTSCONF && echo "DOPKGCHK=no" >> $DEFAULTSCONF
	runScript -p no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "script obeyed the hard-coded default" \
		"" "nothing on stderr"
	cp ${DEFAULTSCONF}.save $DEFAULTSCONF

	echo "DOPKGCHK=no" > ./testubulk.conf
	runScript -C ./testubulk.conf -p no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "setting trumps hard-coded default" \
		"" "nothing on stderr"

	runScript -p no -c no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "command-arg trumps hard-coded default" \
		"" "nothing on stderr"

	runScript -C ./testubulk.conf -p no -c no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkg_chk" "command-arg trumps config file" \
		"" "nothing on stderr"
}

testUpdatePkgsrc() {
	checkDefaultsFile "UPDATEPKGSRC" "yes" "no"

	cp $DEFAULTSCONF ${DEFAULTSCONF}.save
	echo >> $DEFAULTSCONF &&  echo "UPDATEPKGSRC=no" >> $DEFAULTSCONF
	runScript -c no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkgsrc update" "script obeyed the hard-coded default" \
		"" "nothing on stderr"
	cp ${DEFAULTSCONF}.save $DEFAULTSCONF

	echo "UPDATEPKGSRC=no" > ./testubulk.conf
	runScript -C ./testubulk.conf -c no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkgsrc update" "setting trumps hard-coded default" \
		"" "nothing on stderr"

	runScript -c no -p no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkgsrc update" "command-arg trumps hard-coded default" \
		"" "nothing on stderr"

	runScript -C ./testubulk.conf -c no -p no
	checkResults 0 "script exits cleanly" \
		"^Skipping pkgsrc update" "command-arg trumps config file" \
		"" "nothing on stderr"
}

testPkgsrc() {
	checkDefaultsFile "PKGSRC" "/usr/pkgsrc" "/usr/packagesource"

	cp $DEFAULTSCONF ${DEFAULTSCONF}.save
	echo >> $DEFAULTSCONF &&  echo "PKGSRC=/tmp/myfaketestdir" >> $DEFAULTSCONF
	runScript
	checkResults 2 "script dies as expected" \
		"^Updating pkgsrc (/tmp/myfaketestdir)" "script obeyed the hard-coded default" \
		"can't cd to" "stderr complains about fake dir"
	cp ${DEFAULTSCONF}.save $DEFAULTSCONF

	echo "PKGSRC=/tmp/myotherfaketestdir" > ./testubulk.conf
	runScript -C ./testubulk.conf
	checkResults 2 "script dies as expected" \
		"^Updating pkgsrc (/tmp/myotherfaketestdir)" "script obeyed the config-file value" \
		"can't cd to" "stderr complains about fake dir"
}

testBuildLog() {
	checkDefaultsFile "BUILDLOG" "/var/log/ubulk-build.log" "somewhereelse"

	cp $DEFAULTSCONF ${DEFAULTSCONF}.save
	echo >> $DEFAULTSCONF &&  echo "BUILDLOG=./mybuildlog" >> $DEFAULTSCONF
	runScript -c no -p no
	checkResults 0 "script finishes cleanly" \
		"^Logging to ./mybuildlog" "script obeyed the hard-coded default" \
		"" "stderr is empty"
	cp ${DEFAULTSCONF}.save $DEFAULTSCONF

	echo "BUILDLOG=./myotherbuildlog" > ./testubulk.conf
	runScript -c no -p no -C ./testubulk.conf
	checkResults 0 "script finishes cleanly" \
		"^Logging to ./myotherbuildlog" "script obeyed the config-file value" \
		"" "stderr is empty"
}


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

checkDefaultsFile() {
	VAR=$1
	E_VALUE=$2
	T_VALUE=$3

	eval "unset $VAR"
	VALUE=$(
		. $DEFAULTSCONF
		eval "echo \$$VAR"
	)
	assertEquals "$VAR has expected hard-coded value" "$E_VALUE" "$VALUE"

	VALUE=$(
		eval "$VAR=$T_VALUE"
		. $DEFAULTSCONF
		eval "echo \$$VAR"
	)
	assertEquals "$VAR doesn't override already-set value" "$T_VALUE" "$VALUE"
}

. ./shunit2
