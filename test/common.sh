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

#-------------------------------------------------------------------------
# implement a few handy functions
oneTimeSetUp() {
	switchToChroot "$SHUNIT_TMPDIR"

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

runScript() {
	(
		TO_RUN="$1"
		shift

		# a nasty hack, necessary because we are 'source'ing rather than calling
		BASH_SOURCE="`pwd`/$TO_RUN"

		. "$TO_RUN" "$@"

		unset BASH_SOURCE
	) >$OUT 2>$ERR
	RTRN=$?
	cat "$OUT"
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

#-------------------------------------------------------------------------
# use an actual sandbox/chroot to isolate the main system from the tests

switchToChroot() {
	CHROOT_DIR="$1"
	SCRIPT_PATH_PREFIX="${2:-test}"

	TOKEN=".test_is_in_chroot"
	if [ -f /$TOKEN -o "yes" = "$DISABLE_UBULK_TEST_SANDBOX" ]; then
		return
	fi

	if [ ! -n "`command -v mksandbox`" ]; then
		cat << EOF >&2
ERROR: mksandbox is missing.
These tests automatically set up a chroot sandbox to isolate the
system from any real side-effects of the tests.  If you can't or
don't want to install mksandbox (from pkgsrc), the tests can be
run without the sandbox (but this is NOT recommended); just set
DISABLE_UBULK_TEST_SANDBOX=yes in your environment.

Note that creating the sandbox requires root permissions. The test
script will automatically try to use sudo, if the tests are not
run as root. The actual tests themselves will be run as your non-root
user.

EOF
		exit 1
	fi

	echo "Building chroot in $CHROOT_DIR"

	if [ `/usr/bin/id -u` -eq 0 ]; then
		if [ -n "$UBULK_TEST_USER" ]; then
			REAL_USER=$UBULK_TEST_USER
		elif [ -n "$SUDO_USER" ]; then
			REAL_USER=$SUDO_USER
		elif [ -n "$SU_FROM" ]; then
			REAL_USER=$SU_FROM
		elif [ "$USER" != "root" ]; then
			REAL_USER=$USER
		else
			echo >&2 "Can't determine non-root user to run the tests as"
		fi
		DO_SUDO=""
	else
		REAL_USER=`id -un`
		DO_SUDO="sudo"
	fi
	REAL_GROUP=`id -gn`

	trap > .trap.$$ && PRIOR_TRAPS=$(cat .trap.$$) && rm .trap.$$
	trap 'handle_trap EXIT 0' 0
	trap 'handle_trap INT 2' 2
	trap 'handle_trap TERM 15' 15

	: ${PKGDIR:=/usr/pkg}
	$DO_SUDO mksandbox --without-pkgsrc --without-x --rodirs=${PKGDIR} "$CHROOT_DIR" >/dev/null

	WORKDIR="workdir"
	$DO_SUDO mkdir -p "$CHROOT_DIR/$WORKDIR"
	$DO_SUDO chown $REAL_USER:$REAL_GROUP "$CHROOT_DIR/$WORKDIR"
	cp -r ../* "$CHROOT_DIR/$WORKDIR/"

	sudo touch "$CHROOT_DIR/$TOKEN"

	echo "Starting chroot"
	echo
	$DO_SUDO chroot "$CHROOT_DIR" "/$WORKDIR/$SCRIPT_PATH_PREFIX/$0"
	exit $?
}

cleanup() {
	echo "Cleaning up chroot"
	if mount | grep "on $CHROOT_DIR" >/dev/null 2>&1 ; then
		$DO_SUDO $CHROOT_DIR/sandbox umount
	fi
	$DO_SUDO rm -rf $CHROOT_DIR
}

handle_trap() {
	EXIT_CODE=$?
	TRAP_NAME=$1
	TRAP_NUMBER=$2

	# first explitly turn off the traps, then try to restore the prior ones
	trap EXIT
	trap INT
	trap TERM
	eval "$PRIOR_TRAPS"
	if [ -f /$TOKEN ]; then
		exit $EXIT_CODE
	else
		cleanup

		if [ $TRAP_NAME != 'EXIT' ]; then
			kill -s $TRAP_NAME $$

			exit `expr $TRAP_NUMBER + 128`
		else
			exit $EXIT_CODE
		fi
	fi
}

