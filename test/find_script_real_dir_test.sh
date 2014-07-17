#!/bin/sh

SCRIPTNAME=ubulk-build
FOUNDIT="foundit!"

setUp() {
	set -e

	cp ../$SCRIPTNAME $SHUNIT_TMPDIR/
	mkdir $SHUNIT_TMPDIR/lib

	# mock defaults.conf,  which (we believe) is the first thing loaded
	cat <<- EOF > $SHUNIT_TMPDIR/lib/defaults.conf
		echo "$FOUNDIT"
		exit 0
EOF

	INITDIR=`pwd`
	cd $SHUNIT_TMPDIR
}

tearDown() {
	set -e

	cd $INITDIR
	rm -rf $SHUNIT_TMPDIR/*
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
