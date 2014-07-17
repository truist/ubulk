#!/bin/sh

cd test
for t in *test.sh ; do
	echo "# $t"
	./$t
	echo
done
