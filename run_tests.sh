#!/bin/sh

cd test
for testFile in *test.sh ; do
	echo "# $testFile"

	./$testFile
	RTRN=$?
	echo

	if [ 0 -ne $RTRN ]; then
		exit $RTRN
	fi
done
