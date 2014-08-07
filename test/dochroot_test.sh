#!/bin/sh

cd `dirname $0` && . ./common.sh

#-------------------------------------------------------------------------

testScriptDiesIfChrootBreaks() {
	CHROOT='chroot_die'
	runScript -s yes -c yes
	checkResults 23 "script exited with test code" \
		"^Entering chroot ($SANDBOXDIR)" "we tried to enter the chroot" \
		"^Error 23 while \"Entering chroot" "the error is reported on console_err"
}
chroot_die() {
	return 23
}

testLogOutput() {
	CHROOT='chroot_logging'
	runScript -s yes -c yes
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
	runScript -s yes -c yes
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

testChrootExitsNoMatterWhat() {
	CHROOT='chroot_kill'
	runScript -s yes -c yes
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
	runScript -s yes -c yes
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

testSandboxFromPriorRun() {
	CHROOT='chroot_prior_sandbox'
	runScript -s yes -c yes
	checkResults 0 "script made it through second round cleanly" \
		"^Combined results: yes yes" "got through both rounds" \
		"" "nothing on stderr"
}
chroot_prior_sandbox() {
	# we're sneaky - we just call chroot_dirs twice; once to create the dirs
	# and users for us, and again to test that it can handle that.
	chroot_dirs "$@"
	RTRN=$?
	if cat $OUT | grep "a b c d" >/dev/null 2>&1 ; then
		ALL_YES1=yes
		echo > $OUT
	else
		cat $OUT
		return $RTRN
	fi

	chroot_dirs "$@"
	RTRN=$?
	if cat $OUT | grep "a b c d" >/dev/null 2>&1 ; then
		ALL_YES2=yes
	else
		cat $OUT
		return $RTRN
	fi

	console "Combined results: $ALL_YES1 $ALL_YES2"

	return $RTRN
}

INCLUDED_VARS=" PKGLIST
PKGSRC"
EXCLUDED_VARS="BUILDLOG
CHROOT
CONFIG
DOCHROOT
DOPKGCHK
DOPKGSRC
DOSANDBOX
EXTRACHROOTVARS
MKSANDBOX
MKSANDBOXARGS
PKGCHK
SANDBOXDIR"
testScriptVarsArePassedIn() {
	CHROOT='chroot_env'
	runScript -s yes -c yes
	checkResults 0 "script ran cleanly" \
		"^Entering chroot" "we entered the chroot" \
		"" "nothing on stderr" \
		"^CHROOT SET:$" "the environment was reported to us"

	loadDefaultVarList # see common.sh
	echo "$DEFAULTVARS" | while read LINE ; do
		if echo "$INCLUDED_VARS" | grep "$LINE" >/dev/null 2>&1 ; then
			cat "$BUILDLOG" | grep "^$LINE=" >/dev/null 2>&1
			assertTrue "var $LINE was present" $?
		elif echo "$EXCLUDED_VARS" | grep "$LINE" >/dev/null 2>&1 ; then
			cat "$BUILDLOG" | grep "^$LINE=" >/dev/null 2>&1
			assertFalse "var $LINE was not present" $?
		else
			fail "you need to add $LINE to INCLUDED_VARS or EXCLUDED_VARS"
		fi
	done
}
chroot_env() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		echo "CHROOT SET:"
		set
	EOF

	chroot "$@"
}

testExtraVarsArePassedIn() {
	CHROOT='chroot_env'
	EXTRACHROOTVARS='TESTVAR1 TESTVAR2 TESTVAR3'
	TESTVAR1='this one is set'
	TESTVAR2=""
	unset TESTVAR3
	assertTrue "TESTVAR3 is unset" "[ -z ${TESTVAR3+x} ]"

	runScript -s yes -c yes
	checkResults 0 "script ran cleanly" \
		"^Entering chroot" "we entered the chroot" \
		"" "nothing on stderr" \
		"^CHROOT SET:$" "the environment was reported to us"

	cat "$BUILDLOG" | grep "^TESTVAR1='this one is set'$" >/dev/null 2>&1
	assertTrue "a set var was passed in" $?

	cat "$BUILDLOG" | grep "^TESTVAR2=$" >/dev/null 2>&1
	assertTrue "a set-to-empty var was passed in" $?

	cat "$BUILDLOG" | grep "^TESTVAR3=" > /dev/null 2>&1
	assertFalse "an unset var was not passed in" $?
}

testPathsAndUsersAreConfigurableXXX() {
	# scratch -> PBULK_WRKOBJDIR
	# bulklog -> PBULK_BULKLOG
	# pbulk user -> PBULK_UNPRIVILIGED_USER
	startSkipping
	fail "impelement this" # XXX
}

testObeysDoSandbox() {
	# reuse chroot_dirs to build the chroot
	CHROOT='chroot_dirs'
	runScript -s create -c yes
	checkResults 0 "script exited cleanly" \
		"^In chroot; results: a b c d" "chroot has all the right dirs and users" \
		"" "nothing on stderr"

	# then mess it up and run it again with DOSANDBOX=no, to see that it
	# isn't re-configured
	rm -r "$SANDBOXDIR/bulklog"
	assertTrue "we removed /bulklog" $?
	rm -r "$SANDBOXDIR/scratch"
	assertTrue "we removed /scratch" $?

	CHROOT='chroot_dosandbox'
	runScript -s no -c yes
	checkResults 0 "script exited cleanly" \
		"^In chroot; directories missing" "chroot dirs haven't been re-created" \
		"" "nothing on stderr"

	cat "$OUT" | grep "pbulk is still here: pbulk" >/dev/null 2>&1
	assertTrue "pbulk user survives the intervening death of the chroot" $?
}
chroot_dosandbox() {
	cat <<- EOF >> "$SANDBOXDIR$CHROOTSCRIPT"
		if [ ! -d /bulklog -a ! -d /scratch ]; then
			console "In chroot; directories missing"
		else
			console "In chroot: directories present"
			console "ls /: \`ls -l /\`"
		fi

		console "pbulk is still here: \`id -n -u pbulk\`"
	EOF

	chroot "$@"
}

#-------------------------------------------------------------------------

. ./shunit2

