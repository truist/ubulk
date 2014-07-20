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

	SANDBOXDIR="`pwd`/sandbox"
	runScript -s yes
	checkResults 0 "clean exit" \
		"^Mounting sandbox ($SANDBOXDIR)" \
			"sandbox creation is reported to user, and is in the right place" \
		"" "no errors"
	assertTrue "sandbox exists" "[ -f "$SANDBOXDIR/sandbox" ]"
}

# XXX

# can't use relative path for SANDBOXDIR
# sandbox is created
# in specified place
# with specified args (including /var/spool)
# automatically torn down
# warning for out of date mk.conf and/or pkglist


#-------------------------------------------------------------------------

runScript() {
	_runScript "./$SCRIPTNAME" "$@" >/dev/null
}

. ./shunit2
