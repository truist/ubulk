#!/bin/sh

cd `dirname $0` && . ./common.sh

#-------------------------------------------------------------------------

testScriptDiesIfChrootBreaks() {
	CHROOT='chroot_die'
	runScript -s yes
	checkResults 23 "script exited with test code" \
		"^Entering chroot ($SANDBOXDIR)" "we tried to enter the chroot" \
		"^Error 23 while \"Entering chroot" "the error is reported on console_err"
}
chroot_die() {
	return 23
}

testLogOutput() {
	CHROOT='chroot_logging'
	runScript -s yes
	checkResults 0 "script exited cleanly" \
		"^This is chroot console$" "'console' works in chroot" \
		"^This is chroot console_err" "'console_err' works in chroot" \
		"^This is chroot stdout" "chroot stdout goes to external log file"
	if cat $OUT | grep "This is chroot stdout" >/dev/null 2>&1 ; then
		fail "chroot stdout is going to console"
		cat $OUT
	fi
	cat "$BUILDLOG" | grep "^This is chroot stderr" >/dev/null 2>&1
	assertTrue "chroot stderr goes to external log file" $? || cat "$BUILDLOG"
}
chroot_logging() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		echo "This is chroot stdout"
		echo "This is chroot stderr" >&2
		console "This is chroot console"
		console_err "This is chroot console_err"
EOF
	
	chroot "$@"
}

TESTFILE="/tmp/canyouseeme.$$"
testChrootIsMade() {
	touch "$TESTFILE"
	CHROOT='chroot_ismade'
	runScript -s yes
	checkResults 0 "script exited cleanly" \
		"^In chroot; file visible: no" "script in chroot can't see TESTFILE" \
		"" "nothing on stderr"
}
chroot_ismade() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		if [ -f $TESTFILE ]; then
			FILE_VISIBLE=yes
		else
			FILE_VISIBLE=no
		fi
		console "In chroot; file visible: \$FILE_VISIBLE"
EOF

	chroot "$@"
}

testChrootIsExitedNoMatterWhat() {
	CHROOT='chroot_kill'
	runScript -s yes
	checkResults 137 "exit code indicates kill" \
		"^We are in the chroot$" "stdout shows that we were in the chroot" \
		"^Error 137 while \"Entering chroot" "death is reported gracefully" \
		"Killed.*chroot" "Log indicates the error"
}
chroot_kill() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		console "We are in the chroot"
		trap - SIGKILL
		kill -SIGKILL \$\$
EOF

	chroot "$@"
}

testDirsAndUsers() {
	CHROOT='chroot_dirs'
	runScript -s yes
	checkResults 0 "script exited cleanly" \
		"^In chroot; results: a b c d" "chroot has all the right dirs and users" \
		"" "nothing on stderr"
}
chroot_dirs() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		[ -d /bulklog ] && BULKLOG_FOUND=a
		[ -d /scratch ] && SCRATCH_FOUND=b
		id -u pbulk >/dev/null 2>&1 && PBULK_FOUND=c
		[ -n "\$(find /scratch -user pbulk -print -prune -o -prune)" ] && SCRATCH_OWNER=d

		console "In chroot; results: \$BULKLOG_FOUND \$SCRATCH_FOUND \$PBULK_FOUND \$SCRATCH_OWNER"
EOF

	chroot "$@"
}

testDirsAndUsersProblemCausesDeath() {
	fail "implement this"
}

testEnvironmentIsPassedIn() {
	fail "implement this"
	fail "make paths and users configurable"
}

testDirsAndUsersNoSandbox() {
}

#-------------------------------------------------------------------------

. ./shunit2

