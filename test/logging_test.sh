#!/bin/sh

. ./common.sh

localOneTimeSetUp() {
	LOG="$SHUNIT_TMPDIR/log"
}

#-------------------------------------------------------------------------

testLogingSetup() {
	(
		. $UTILSH
	) >$OUT 2>$ERR
	RTRN=$?
	checkResults 1 "if we don't set LOGPATH, we die" \
		"" "nothing on stdout" \
		"must set LOGPATH" "we're told what the problem is"

	(
		LOGPATH="$LOG"
		. $UTILSH
	) >$OUT 2>$ERR
	RTRN=$?
	checkResults 0 "when we set LOGPATH, everything is happy" \
		"^Logging to $LOG" "stdout tells us where we're logging" \
		"" "nothing on stderr"
}

testOutputDestinationsAndLineOrdering() {
	(
		LOGPATH="$LOG"
		. $UTILSH
		echo "1: stdout goes to log"
		echo >&2 "2: stderr goes to log"
		console "3: console goes to 'real' stdout and to log"
		console_err "4: console err goes to 'real' stderr and to log"
		echo "5: CONSOLEOUT goes to 'real' stdout and not log" > $CONSOLEOUT
		echo "6: CONSOLEERR goes to 'real' stderr and not log" > $CONSOLEERR
	) >$OUT 2>$ERR
	RTRN=$?

	assertEquals "ran cleanly" "0" "$RTRN"

	E_LOG="$(cat <<- EOF
		1: stdout goes to log
		2: stderr goes to log
		3: console goes to 'real' stdout and to log
		4: console err goes to 'real' stderr and to log
EOF
	)"
	checkLog "log got stdout, stderr, console, and console_err" "$E_LOG"

	E_OUT="$(cat <<- EOF
		Logging to $LOG
		3: console goes to 'real' stdout and to log
		5: CONSOLEOUT goes to 'real' stdout and not log
EOF
	)"
	checkOut "stdout got console, CONSOLEOUT" "$E_OUT"

	E_ERR="$(cat <<- EOF
		4: console err goes to 'real' stderr and to log
		6: CONSOLEERR goes to 'real' stderr and not log
EOF
	)"
	checkErr "stderr got console_err, CONSOLEERR" "$E_ERR"
}

testDieWorksWithNoConsoleCall() {
	(
		LOGPATH="$LOG"
		. $UTILSH
		die 23
	) >$OUT 2>$ERR
	RTRN=$?

	assertEquals "we exited as expected" 23 $RTRN
	checkOut "nothing extra on stdout" "Logging to $LOG"
	checkLog "log shows the error" 'Error 23 while ""'

	E_ERR="$(cat <<- EOF
		Error 23 while ""
		 > 

		See $LOG for details
EOF
	)"
	checkErr "real stderr shows (somewhat broken) failure info, and log file" "$E_ERR"
}

testDieAfterConsoleCall() {
	START="Starting some process"
	(
		LOGPATH="$LOG"
		. $UTILSH
		console "$START"
		die 23
	) >$OUT 2>$ERR
	RTRN=$?

	assertEquals "we exited as expected" 23 $RTRN

	E_OUT="$(cat <<- EOF
		Logging to $LOG
		$START
EOF
	)"
	checkOut "stdout shows what we expect" "$E_OUT"


	E_ERR="$(cat <<- EOF
		Error 23 while "$START"
		 > 

		See $LOG for details
EOF
	)"
	checkErr "stderr shows the error and the prior console message" "$E_ERR"

	E_LOG="$(cat <<- EOF
		$START
		Error 23 while "$START"
EOF
	)"
	checkLog "log shows the start and the error, but not the rest" "$E_LOG"
}

testLogLinesLimitBasics() {
	(
		LOGPATH="$LOG"
		. $UTILSH
		echo "$LOGLINESLIMIT"  # (to log file)
	) >$OUT 2>$ERR
	checkLog "default LOGLINESLIMIT is 10" "10"

	(
		LOGPATH="$LOG"
		LOGLINESLIMIT=5
		. $UTILSH
		echo "$LOGLINESLIMIT"  # (to log file)
	) >$OUT 2>$ERR
	checkLog "can override LOGLINESLIMIT" "5"
}

testDieLoggingWithLittleLogging() {
	START="Starting some process"
	(
		LOGPATH="$LOG"
		. $UTILSH
		console "$START"
		echo one
		echo two
		die 23
	) >$OUT 2>$ERR
	RTRN=$?

	assertEquals "we exited as expected" 23 $RTRN

	E_OUT="$(cat <<- EOF
		Logging to $LOG
		$START
EOF
	)"
	checkOut "stdout shows what we expect" "$E_OUT"

	E_ERR="$(cat <<- EOF
		Error 23 while "$START"
		 > one
		 > two

		See $LOG for details
EOF
	)"
	checkErr "stderr shows the error, the prior console message, and the following logs" "$E_ERR"

	E_LOG="$(cat <<- EOF
		$START
		one
		two
		Error 23 while "$START"
EOF
	)"
	checkLog "log shows the start, the logs, and the error, but not the rest" "$E_LOG"
}

testDieLoggingWithLotsOfLogging() {
	START="Starting some process"
	(
		LOGPATH="$LOG"
		LOGLINESLIMIT=2   # assume this works
		. $UTILSH
		console "$START"
		echo one
		echo two
		echo three
		echo four
		echo five
		echo six
		echo seven
		die 23
	) >$OUT 2>$ERR
	RTRN=$?

	assertEquals "we exited as expected" 23 $RTRN

	E_OUT="$(cat <<- EOF
		Logging to $LOG
		$START
EOF
	)"
	checkOut "stdout shows what we expect" "$E_OUT"

	E_ERR="$(cat <<- EOF
		Error 23 while "$START"
		 > one
		 > two
		 > [...snip...]
		 > six
		 > seven

		See $LOG for details
EOF
	)"
	checkErr "stderr shows the error, the prior console message, and a subset of the following logs" "$E_ERR"

	E_LOG="$(cat <<- EOF
		$START
		one
		two
		three
		four
		five
		six
		seven
		Error 23 while "$START"
EOF
	)"
	checkLog "log shows the start, the logs, and the error, but not the rest" "$E_LOG"
}

testDieLoggingWithZeroLogLinesLimit() {
	START="Starting some process"
	(
		LOGPATH="$LOG"
		LOGLINESLIMIT=0
		. $UTILSH
		console "$START"
		echo one
		echo two
		die 23
	) >$OUT 2>$ERR
	RTRN=$?

	assertEquals "we exited as expected" 23 $RTRN

	E_OUT="$(cat <<- EOF
		Logging to $LOG
		$START
EOF
	)"
	checkOut "stdout shows what we expect" "$E_OUT"

	E_ERR="$(cat <<- EOF
		Error 23 while "$START"

		See $LOG for details
EOF
	)"
	checkErr "stderr shows the error, the prior console message, and NO following logs" "$E_ERR"

	E_LOG="$(cat <<- EOF
		$START
		one
		two
		Error 23 while "$START"
EOF
	)"
	checkLog "log shows the start, the logs, and the error, but not the rest" "$E_LOG"
}

#-------------------------------------------------------------------------

checkOut() {
	assertEquals "$1" "$2" "$(cat $OUT)"
}

checkErr() {
	assertEquals "$1" "$2" "$(cat $ERR)"
}

checkLog() {
	assertEquals "$1" "$2" "$(cat $LOG)"
}

. ./shunit2 
