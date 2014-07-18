#!/bin/sh

. ./common.sh

FOUNDIT="foundit!"

localSetUp() {

	# mock defaults.conf,  which (for now) is the first thing loaded
	cat <<- EOF > $SHUNIT_TMPDIR/lib/defaults.conf
		echo "$FOUNDIT"
		exit 0
EOF
}

#-----------------------------------------------------------------

testDirectCallFromItsDir() {
	assertEquals "Found lib dir" "$FOUNDIT" "$(./$SCRIPTNAME)"
}

testDirectCallFromOtherDir() {
	mkdir other && cd other
	assertEquals "Found lib dir" "$FOUNDIT" "$(../$SCRIPTNAME)"
}

testSameNameAbsPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s $SHUNIT_TMPDIR/$SCRIPTNAME
	assertEquals "Found lib dir" "$FOUNDIT" "$(./$SCRIPTNAME)"
}

testSameNameRelPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s ../$SCRIPTNAME
	assertEquals "Found lib dir" "$FOUNDIT" "$(./$SCRIPTNAME)"
}

testDiffNameAbsPathSymlinkFromSameDir() {
	ln -s $SHUNIT_TMPDIR/$SCRIPTNAME newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(./newname.sh)"
}

testDiffNameRelPathSymlinkFromSameDir() {
	ln -s ./$SCRIPTNAME newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(./newname.sh)"
}

testDiffNameAbsPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s $SHUNIT_TMPDIR/$SCRIPTNAME ./newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(./newname.sh)"
}

testDiffNameRelPathSymlinkFromOtherDir() {
	mkdir other && cd other
	ln -s ../$SCRIPTNAME ./newname.sh
	assertEquals "Found lib dir" "$FOUNDIT" "$(./newname.sh)"
}

. ./shunit2
