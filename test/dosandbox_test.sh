#!/bin/sh

cd `dirname $0` && . ./common.sh

#-------------------------------------------------------------------------

testCreateSandbox() {
	SANDBOXDIR="./sandbox"
	runScript -s yes
	checkResults 1 "error exit" \
		"^Mounting sandbox ($SANDBOXDIR)" \
			"sandbox creation is reported to user, and is in the right place" \
		"SANDBOXDIR must be an absolute path ($SANDBOXDIR)" \
			"script catches a relative path for sandbox dir"

	assertTrue "sandbox doesn't exist yet" "[ ! -f "$SANDBOXDIR/sandbox" ]"
	SANDBOXDIR="`pwd`/sandbox"
	MKSANDBOX="mkSandboxCreateSandbox"
	runScript -s yes
	checkResults 0 "clean exit" \
		"^Mounting sandbox ($SANDBOXDIR)" \
			"sandbox creation is reported to user, and is in the right place" \
		"" "no errors"
}
mkSandboxCreateSandbox() {
	mksandbox "$@"
	RTRN=$?

	assertTrue "sandbox exists" "[ -f "$SANDBOXDIR/sandbox" ]"

	return $RTRN
}

testArgsAreObeyed() {
	# test is based on the default arg of --rwdirs=/var/spool

	# remember, we're in an outer sandbox/chroot, so the stuff we do here
	# doesn't actually affect the real host

	TEST_FILE="var/spool/ubulk-test-$$"
	assertTrue "test file doesn't exist yet" "[ ! -f '/$TEST_FILE' ]"

	MKSANDBOX=mkSandboxArgsAreObeyed
	runScript -s yes
}
mkSandboxArgsAreObeyed() {
	mksandbox "$@"
	RTRN=$?

	assertTrue "we can 'touch' the test file" "$(touch "$SANDBOXDIR/$TEST_FILE"; echo $?)"
	assertTrue "after which, the file also exists in the mount base (so /var/spool was mounted rw)" \
		"[ -f '/$TEST_FILE' ]"

	return $RTRN
}

testCleansMountAfterCleanExit() {
	POST_SANDBOX_EVENT=0
	setupMountForCleaning

	checkResults $POST_SANDBOX_EVENT "exited with our test code" \
		"^Unmounting sandbox" "stdout says what's happening" \
		"" "nothing on stderr"
}

testCleansMountAfterErrorExit() {
	POST_SANDBOX_EVENT=23
	setupMountForCleaning

	checkResults $POST_SANDBOX_EVENT "exited with our test code" \
		"^Unmounting sandbox" "stdout says what's happening" \
		"" "nothing on stderr"
}

testCleansMountAfterInterrupt() {
	POST_SANDBOX_EVENT="INTERRUPT"
	setupMountForCleaning

	checkResults $((9 + 128)) "exited with term code" \
		"^Unmounting sandbox" "stdout says what's happening" \
		"^Caught signal 'INT'" "stderr explains the signal"
}

testCleansMountAfterTerm() {
	POST_SANDBOX_EVENT="TERM"
	setupMountForCleaning

	checkResults $((15 + 128)) "exited with term code" \
		"^Unmounting sandbox" "stdout says what's happening" \
		"^Caught signal 'TERM'" "stderr explains the signal"
}

setupMountForCleaning() {
	GREPSTR="on $SHUNIT_TMPDIR.\+ type null"
	if mount | grep "$GREPSTR" >/dev/null 2>&1 ; then
		fail "Earlier mounts are still present"
	fi

	assertTrue "sandbox doesn't exist yet" "[ ! -f "$SANDBOXDIR/sandbox" ]"

	MKSANDBOX=killerMkSandbox
	runScript -s yes

	assertTrue "sandbox was deleted" "[ ! -f "$SANDBOXDIR/sandbox" ]"
}

killerMkSandbox() {
	mksandbox "$@"
	RTRN=$?

	assertTrue "sandbox was created" "[ -f "$SANDBOXDIR/sandbox" ]"

	# note that this way of testing forces the script to have set up the traps
	# *before* calling mksandbox (which is what we want)
	getSubshellPid
	if [ "TERM" = "$POST_SANDBOX_EVENT" ]; then
		kill -SIGTERM $SUBSHELL_PID
	elif [ "INTERRUPT" = "$POST_SANDBOX_EVENT" ]; then
		kill -SIGINT $SUBSHELL_PID
	else
		exit $POST_SANDBOX_EVENT
	fi

	# just in case we survive this far
	return $RTRN
}

getSubshellPid() {
	# XXX not POSIX, and a big hack, but it seem to be the best way
	# other than using bash explicitly
	SUBSHELL_PID=$(sh -c 'ps -p $$ -o ppid=')
}

# XXX

# - can't use relative path for SANDBOXDIR
# - sandbox is created
# - in specified place
# - with specified args (including /var/spool)
# automatically torn down
# warning for out of date mk.conf and/or pkglist


#-------------------------------------------------------------------------

runScript() {
	_runScript "./$SCRIPTNAME" "$@" >/dev/null
}

. ./shunit2
