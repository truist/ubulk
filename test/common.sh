#-------------------------------------------------------------------------
# set a few handy globals
SCRIPTNAME=ubulk-build
DEFAULTSCONF=lib/defaults.conf
UTILSH=lib/util.sh

#-------------------------------------------------------------------------
# go to insane lengths to try to avoid touching the real system
# (see way below for some handy functions, too)

# point path-based settins to a local dir
CONFIG=./ubulk.conf
PKGSRC=./pkgsrc
BUILDLOG=./ubulk-build.log

# turn every build step off
DOPKGSRC=no
DOPKGCHK=no

# check that we got all the variables
TMPSCRIPT="./.tmpscript"
cat <<- EOF >$TMPSCRIPT
	#!/bin/sh
	BEFORE=\`set\`
	. ../$DEFAULTSCONF
	AFTER=\`set\`
	echo "\$BEFORE" "\$AFTER" | sort | uniq -u | grep "=" | grep -v "^PS.=" | grep -v "^PWD="
EOF
chmod +x $TMPSCRIPT
DEFAULTVARS=$(
	env -i $TMPSCRIPT | sed -r 's/^(.+)=.*$/\1/'
)
rm $TMPSCRIPT
echo "$DEFAULTVARS" | while read LINE ; do
	if [ -z "$(eval "echo \$$LINE")" ]; then
		echo >&2 "$DEFAULTSCONF sets $LINE but this test doesn't override it"
	fi
done

# unset PATH (way at the bottom) so the code won't run any external commands.
# then intercept every single external command call to try to avoid accidentally
# modifying "real" things (mainly if/when tests don't behave as expected),
# re-implementing some things to make them 'safe'. note that this doesn't
# cover a whole bunch of issues, including redirection to a file. the right
# answer here is a chroot, but that requires root.
makeExplicitCommand() {
	eval "alias $1=`command -v $1`"
}
makeExplicitCommand "awk"
makeExplicitCommand "cat"
makeExplicitCommand "cut"
makeExplicitCommand "dirname"
makeExplicitCommand "egrep"
makeExplicitCommand "expr"
makeExplicitCommand "grep"
makeExplicitCommand "head"
makeExplicitCommand "ls"
makeExplicitCommand "mktemp"
makeExplicitCommand "readlink"
makeExplicitCommand "sed"
makeExplicitCommand "tail"
makeExplicitCommand "tee"
makeExplicitCommand "tr"
makeExplicitCommand "wc"
makeExplicitCommand "xargs"

makeFilteringCommand() {
	local COMMAND
	COMMAND=$1

	local INITIAL_PWD
	INITIAL_PWD=`pwd`

	local FILTERINGCOMMAND
	FILTERINGCOMMAND="$(cat <<- EOF
		REAL$COMMAND=\`command -v $COMMAND\`
		${COMMAND}() {
			\$REAL$COMMAND "\$@"
			RTRN=\$?

			for LASTARG; do :; done
			OK=0
			if echo "\$LASTARG" | grep "^/tmp/" >/dev/null 2>&1 ; then
				OK=1
			elif echo "\$LASTARG" | grep "^[^/]\+" >/dev/null 2>&1 ; then
				if echo "\`pwd\`" | grep "^/tmp/" >/dev/null 2>&1 ; then
					OK=1
				elif echo "\`pwd\`" | grep "^${INITIAL_PWD}" >/dev/null 2>&1 ; then
					OK=1
				fi
			fi
			if [ \$OK -eq 1 ]; then
				return \$RTRN
			else
				echo >&2 "Tests can only $COMMAND in local (\`pwd\`) and tmp dirs: \$@"
				exit 1
			fi
		}
EOF
	)"
	eval "$FILTERINGCOMMAND"
}
makeFilteringCommand "chmod"
makeFilteringCommand "cp"
makeFilteringCommand "ln"
makeFilteringCommand "mkdir"
makeFilteringCommand "mv"
makeFilteringCommand "rm"

# we're never going to call the real git
GIT_RESULT=0
git() {
	return $GIT_RESULT
}

# and now the final step:
PATH=
#set -x

#-------------------------------------------------------------------------
# implement a few handy functions
oneTimeSetUp() {
	OUT="$SHUNIT_TMPDIR/stdout"
	ERR="$SHUNIT_TMPDIR/stderr"

	if fn_exists "localOneTimeSetUp" ; then
		localOneTimeSetUp
	fi
}

setUp() {
	local - && set -e

	cp ../$SCRIPTNAME $SHUNIT_TMPDIR/
	mkdir $SHUNIT_TMPDIR/lib
	cp ../lib/* $SHUNIT_TMPDIR/lib/

	if fn_exists "localSetUp" ; then
		localSetUp
	fi

	INITDIR=`pwd`
	cd $SHUNIT_TMPDIR
}

tearDown() {
	local - && set -e

	cd $INITDIR
	rm -rf $SHUNIT_TMPDIR/*
}

checkResults() {
	local - && set -v
	E_EXIT=$1
	EXIT_MSG="$2"
	E_OUT="$3"
	OUT_MSG="$4"
	E_ERR="$5"
	ERR_MSG="$6"

	if [ $E_EXIT -eq 0 ]; then
		assertTrue "$EXIT_MSG" $RTRN || echo "($RTRN)"
	else
		assertFalse "$EXIT_MSG" $RTRN || echo "($RTRN)"
	fi

	if [ "" = "$E_OUT" ]; then
		assertNull "$OUT_MSG" "$(cat $OUT)" || cat $OUT
	else
		echo "$(cat $OUT)" | grep "$E_OUT" >/dev/null 2>&1
		assertTrue "$OUT_MSG" $? || cat $OUT
	fi

	if [ "" = "$E_ERR" ]; then
		assertNull "$ERR_MSG" "$(cat $ERR)" || cat $ERR
	else
		echo "$(cat $ERR)" | grep "$E_ERR" >/dev/null 2>&1
		assertTrue "$ERR_MSG" $? || cat $ERR
	fi
}

fn_exists() {
	type $1 | grep >/dev/null 2>&1 'function'
}

