#!/bin/sh

cd `dirname $0` && . ./common.sh

#-------------------------------------------------------------------------

testBootstrap() {
	CHROOT='chroot_bootstrap'
	runScript -s yes -c yes
	checkResults 0 "script exited cleanly" \
		"^bootstrap dir exists" "bootstrap dir exists" \
		"" "nothing on stderr"
	cat "$OUT" | grep "^pkgdb exists" >/dev/null 2>&1
	assertTrue "pkgdb exists" $?
}
chroot_bootstrap() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		[ -d /usr/pkg_bulk ] && console "bootstrap dir exists"
		[ -d /usr/pkg_bulk/.pkgdb ] && console "pkgdb exists"
	EOF
	
	chroot "$@"
}

# bootstrap happens
# build fails if bootstrap fails
# old dir is removed first
# mk.conf is correct
# build PATH is correct
# pbulk is installed, into the right place
# pbulk is not installed chroot-wide
# obey config option not to do it

#-------------------------------------------------------------------------

. ./shunit2

