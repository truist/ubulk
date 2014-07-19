#!/bin/sh

SCRIPTNAME=`basename $0`
TMPDIR=`mktemp -d 2>/dev/null || mktemp -d -t "$SCRIPTNAME"`

cd "`dirname $0`/test" && . "./common.sh"
switchToChroot "$TMPDIR" "."

for testFile in *test.sh ; do
	echo "# $testFile"

	./$testFile
	RTRN=$?
	echo

	if [ 0 -ne $RTRN ]; then
		exit $RTRN
	fi
done
