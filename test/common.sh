#-------------------------------------------------------------------------
# set a few handy globals

SCRIPTNAME=ubulk-build
DEFAULTSCONF=lib/defaults.conf
UTILSH=lib/util.sh

#-------------------------------------------------------------------------
# some test helpers (and auto-setup)

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
	if [ -d "$SHUNIT_TMPDIR/lib" ]; then
		# this happens if DELETE_CHROOT is 'no'
		mv "$SHUNIT_TMPDIR/lib" "$SHUNIT_TMPDIR/lib.prior"
	fi
	mkdir $SHUNIT_TMPDIR/lib
	cp ../lib/* $SHUNIT_TMPDIR/lib/

	if fn_exists "localSetUp" ; then
		localSetUp
	fi

	INITDIR=`pwd`
	cd $SHUNIT_TMPDIR

	neuterPaths "$SHUNIT_TMPDIR"
}

tearDown() {
	local - && set -e

	cd $INITDIR
	if [ "no" != "$DELETE_CHROOT" ]; then 
		rm -rf $SHUNIT_TMPDIR/*
	fi
}

_runScript() {
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
	E_LOG="$7"
	LOG_MSG="$8"

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

	if [ "" != "$E_LOG" ]; then
		echo "$(cat "$BUILDLOG")" | grep "$E_LOG" >/dev/null 2>&1
		assertTrue "$LOG_MSG" $? || cat "$BUILDLOG"
	fi
}

fn_exists() {
	type $1 | grep >/dev/null 2>&1 'function'
}

neuterPaths() {
	PATHROOT="$1"
	# point path-based settings to a local dir
	CONFIG="$PATHROOT/ubulk.conf"
	PKGSRC="$PATHROOT/pkgsrc"
	BUILDLOG="$PATHROOT/ubulk-build.log"
	PKGLIST="$PATHROOT/pkglist"

	# turn every build step off
	DOPKGSRC=no
	DOPKGCHK=no

	# odds-and-ends
	PKGCHK=pkg_chk

	# check that we got all the variables
	TMPSCRIPT="./.tmpscript"
	cat <<- EOF >$TMPSCRIPT
		#!/bin/sh
		BEFORE=\`set\`
		. $DEFAULTSCONF
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
}

#-------------------------------------------------------------------------
# use an actual sandbox/chroot to isolate the main system from the tests

switchToChroot() {
	CHROOT_DIR="$1"
	SCRIPT_PATH_PREFIX="${2:-test}"

	TOKEN=".test_is_in_chroot"
	if [ -f /$TOKEN -o "yes" = "$DISABLE_UBULK_TEST_SANDBOX" ]; then
		if [ "no" = "$DELETE_CHROOT" ]; then 
			# disable shunit2's traps
			trap 'handle_trap EXIT 0' 0
			trap 'handle_trap INT 2' 2
			trap 'handle_trap TERM 15' 15
		fi
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

	echo "Mounting chroot in $CHROOT_DIR"

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
	: ${PKGSRCDIR:=/usr/pkgsrc}
	: ${PKG_DBDIR:=/var/db/pkg}
	$DO_SUDO mksandbox --without-pkgsrc --without-x \
		--rodirs=$PKGDIR,$PKGSRCDIR,$PKG_DBDIR \
		"$CHROOT_DIR" >/dev/null

	WORKDIR="workdir"
	$DO_SUDO mkdir -p "$CHROOT_DIR/$WORKDIR"
	$DO_SUDO chown $REAL_USER:$REAL_GROUP "$CHROOT_DIR/$WORKDIR"
	cp -r ../* "$CHROOT_DIR/$WORKDIR/"

	$DO_SUDO touch "$CHROOT_DIR/$TOKEN"

	BOOTSTRAP="/tmp/bootstrap.$$"
	cat <<- EOF > "$CHROOT_DIR/$BOOTSTRAP"
		#!/bin/sh
		cd /$WORKDIR/$SCRIPT_PATH_PREFIX/
		DELETE_CHROOT=$DELETE_CHROOT $0
		exit \$?
EOF
	$DO_SUDO chmod +x "$CHROOT_DIR/$BOOTSTRAP"

	echo "Switching into chroot"
	echo "---------------------"
	echo
	$DO_SUDO chroot -u $REAL_USER -g $REAL_GROUP "$CHROOT_DIR" "$BOOTSTRAP"
	RTRN=$?

	# shunit expects tests to be run, but all our tests were run in the chroot
	__shunit_reportGenerated=${SHUNIT_TRUE}

	exit $RTRN
}

cleanup() {
	echo
	echo "---------------------"
	if mount | grep "on $CHROOT_DIR" >/dev/null 2>&1 ; then
		echo "Unmounting chroot"
		$DO_SUDO $CHROOT_DIR/sandbox umount
	fi
	if [ "no" != "$DELETE_CHROOT" ]; then 
		echo "Deleting chroot"
		$DO_SUDO rm -rf "$CHROOT_DIR"
	fi
}

handle_trap() {
	EXIT_CODE=$?
	TRAP_NAME=$1
	TRAP_NUMBER=$2

	# first explitly turn off the traps, then try to restore the prior ones
	trap EXIT
	trap INT
	trap TERM
	if [ "no" != "$DELETE_CHROOT" ]; then 
		eval "$PRIOR_TRAPS"
	fi

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

