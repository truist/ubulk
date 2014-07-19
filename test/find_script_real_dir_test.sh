#!/bin/sh

. ./common.sh

FOUNDIT="foundit!"

localSetUp() {

	# mock defaults.conf,  which (for now) is the first thing loaded
	cat <<- EOF > $SHUNIT_TMPDIR/$DEFAULTSCONF
		echo "$FOUNDIT"
		exit 0
EOF
}

#-------------------------------------------------------------------------

testDirectCallFromItsDir() {
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ./$SCRIPTNAME)"
}

testDirectCallFromOtherDir() {
	mkdir other && cd other
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ../$SCRIPTNAME)"
}

testSameNameAbsPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s $SHUNIT_TMPDIR/$SCRIPTNAME
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ./$SCRIPTNAME)"
}

testSameNameRelPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s ../$SCRIPTNAME
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ./$SCRIPTNAME)"
}

testDiffNameAbsPathSymlinkFromSameDir() {
	ln -s $SHUNIT_TMPDIR/$SCRIPTNAME newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ./newname.sh)"
}

testDiffNameRelPathSymlinkFromSameDir() {
	ln -s ./$SCRIPTNAME newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ./newname.sh)"
}

testDiffNameAbsPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s $SHUNIT_TMPDIR/$SCRIPTNAME ./newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ./newname.sh)"
}

testDiffNameRelPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s ../$SCRIPTNAME ./newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(runScript ./newname.sh)"
}

#-------------------------------------------------------------------------

runScript() {
	(
		TO_RUN="$1"
		shift

		# a nasty hack, necessary because we are 'source'ing rather than calling
		BASH_SOURCE="`pwd`/$TO_RUN"

		. "$TO_RUN" "$@"

		unset BASH_SOURCE
	) >$OUT 2>&1
	cat "$OUT"
}

. ./shunit2
