#!/bin/sh

cd `dirname $0` && . ./common.sh

localOneTimeSetUp() {
	(
		# in a subshell, so the settings are temporary
		# remember, we are already in a chroot
		# make the sandbox outside SHUNIT_TMPDIR, so common.sh leaves it alone
		neuterPaths "/tmp"
		"$MKSANDBOX" $MKSANDBOXARGS "$SANDBOXDIR" >/dev/null 2>&1
		assertTrue "sandbox exists" "[ -f "$SANDBOXDIR/sandbox" ]"
	)
}

localSetUp() {
	SANDBOXDIR="/tmp/sandbox"
}

localOneTimeTearDown() {
	"$SANDBOXDIR/sandbox" umount
}

#-------------------------------------------------------------------------

testChrootDiesIfChrootBreaks() {
	CHROOT='chroot_die'
	runScript
	checkResults 23 "script exited with test code" \
		"^Entering chroot ($SANDBOXDIR)" "we tried to enter the chroot" \
		"^Error 23 while \"Entering chroot" "the error is reported on console_err"
}
chroot_die() {
	return 23
}

testLogOutput() {
	CHROOT='chroot_logging'
	runScript
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
#	runScript -s
#	checkResults 0 "script exited cleanly" \
#		"^In chroot; file visible: 1" "script in chroot can't see TESTFILE" \
#		"" "nothing on stderr"
}
chroot_ismade() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		FILE_VISIBLE=\$([ -f $TESTFILE ])
		echo \"In chroot; file visible: \$FILE_VISIBLE\"
EOF

	chroot "$@"
}

testChrootIsExitedNoMatterWhat() {
}

testDirsAndUsers() {
}

testDirsAndUsersNoSandbox() {
}

#-------------------------------------------------------------------------

. ./shunit2
