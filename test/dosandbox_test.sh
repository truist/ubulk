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
	runScript -s yes
	checkResults 0 "clean exit" \
		"^Mounting sandbox ($SANDBOXDIR)" \
			"sandbox creation is reported to user, and is in the right place" \
		"" "no errors"
	assertTrue "sandbox exists" "[ -f "$SANDBOXDIR/sandbox" ]"
}

testArgsAreObeyed() {
	# test is based on the default arg of --rwdirs=/var/spool

	# remember, we're in an outer sandbox/chroot, so the stuff we do here
	# doesn't actually affect the real host

	TEST_FILE="var/spool/ubulk-test-$$"
	assertTrue "test file doesn't exist yet" "[ ! -f '/$TEST_FILE' ]"
	runScript -s yes
	assertTrue "we can 'touch' the test file" "$(touch "$SANDBOXDIR/$TEST_FILE"; echo $?)"
	assertTrue "after which, the file also exists in the mount base (so /var/spool was mounted rw)" \
		"[ -f '/$TEST_FILE' ]"
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
