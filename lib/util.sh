# redirect stdout and stderr to a file, but leave a way to send messages
# to the 'real' stdout and stderr
if [ -n "$LOGPATH" ]; then
	echo -n >"$LOGPATH"
	exec 3>&1 4>&2 1>"$LOGPATH" 2>&1
	CONSOLEOUT=/dev/fd/3
	CONSOLEERR=/dev/fd/4
	echo >$CONSOLEOUT "Logging to $LOGPATH"
else
	echo >&2 "ERROR: must set LOGPATH before slurping util.sh"
	exit 1
fi

# handy method for printing stuff to the user; works in concert with die()
LASTCONSOLE=""
LASTPOS=0
console() {
	echo "$@" | tee $CONSOLEOUT
	LASTCONSOLE="$@"
	LASTPOS=$(($(ls -nl "$LOGPATH" | awk '{print $5}') + 1))
}

console_err() {
	echo "$@" | tee $CONSOLEERR
}

: ${LOGLINESLIMIT:=10}
# get only those log lines that appeared since we last called console()
# (this is probably horrible memory-wise for large logs)
recent_logs() {
	if log_lines_exceed_limit ; then
		LOGHEAD=$(tail -c +$LASTPOS "$LOGPATH" | head -n $LOGLINESLIMIT)
		LOGTAIL=$(tail -n $LOGLINESLIMIT "$LOGPATH")
		LOGLINES=$(echo "$LOGHEAD" ; echo "[...snip...]" ; echo "$LOGTAIL")
	else
		LOGLINES=$(tail -c +$LASTPOS "$LOGPATH")
	fi
	echo "$LOGLINES"
}
# performance optimization
log_lines_exceed_limit() {
	LOGLINES=$(tail -c +$LASTPOS "$LOGPATH")
	LOGLINESCOUNT=$(echo "$LOGLINES" | wc -l)
	[ $LOGLINESCOUNT -gt $(($LOGLINESLIMIT * 2)) ]
}

# quit, but give as much context as possible first
die() {
	local exitcode
	exitcode=$1; shift

	if [ 0 -lt $LOGLINESLIMIT ]; then
		RECENTLOGS=$(recent_logs)
	fi

	console_err "Error $exitcode while \"$LASTCONSOLE\""

	if [ 0 -lt $LOGLINESLIMIT ]; then
		# only write to console (err), not to log
		echo "$RECENTLOGS" | sed 's/^/ > /' >$CONSOLEERR
	fi

	# only write to console (err), not to log
	echo > $CONSOLEERR
	echo "See $LOGPATH for details" >$CONSOLEERR

	exit ${exitcode}
}

register_traps() {
	TRAP_CALLBACK="$1"

	trap 'handle_trap EXIT 0' 0
	trap 'handle_trap INT 2' 2
	trap 'handle_trap TERM 15' 15
}

disable_traps() {
	trap EXIT
	trap INT
	trap TERM
}

handle_trap() {
	EXIT_CODE=$?
	TRAP_NAME=$1
	TRAP_NUMBER=$2

	disable_traps

	$TRAP_CALLBACK

	if [ $TRAP_NAME != 'EXIT' ]; then
		# propagate the trap, now that we're done and aren't catching it anymore
		# (and do it in a way that's test-compatible)
		if [ -z "$SUBSHELL_PID" ]; then
			kill -s $TRAP_NAME $$
		fi
		# exit according to convention, if we're still here
		exit `expr $TRAP_NUMBER + 128`
	else
		exit $EXIT_CODE
	fi
}

