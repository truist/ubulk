# ubulk dev backlog

## Done

* Do a manual bulk build with pbulk
* Do a scripted install of all desired packages
* Make a backlog

## Build Backlog

* Formal script that can update pkgsrc
    - config file with pkgsrc dir (/usr/pkgsrc)
    - git-only
    - die on error
* Log results and be ready to be run from cron
    - config log file (/var/log/ubulk.log)
    - summary to stdout / details to log file
    - output path to log file
    - test running it from cron
* Option to use pkg_chk to see what's new (in log output)
    - config setting (yes)
    - command-line arg to override config setting
* Option and command-arg to skip pkgsrc update
    - so you can just do the pkg_chk (now) or the build (later)
* Create the sandbox
    - config location (/usr/sandbox)
    - config mksandbox args (--without-x)
    - mksandbox --rwdirs=/var/spool
    - before running pkg_chk
    - install mksandbox if necessary
* Un-create the sandbox, on new run
    - before pkgsrc update
    - if it's already mounted, unmount it
    - if it already exists, delete it
* Option and command-arg to ignore/assume sandbox state
    - i.e. if you just want to leave the prior sandbox up
    - if set, warn if system /etc/mk.conf is newer than sandbox /etc/mk.conf
* Update "install mksandbox" step to use an isolated build and install location
    - follow pattern from installing pbulk
    - should work even if the rest of pkgsrc is messy
    - workdirs should be totally isolated
    - ideally don't rebuild dependencies that don't need it
    - don't create a package (explicitly; it's ok if the system mk.conf triggers it)
* Chroot and prep for pbulk
    - after sandbox setup
    - run a script once inside
    - no matter what happens to that script, exit the chroot when finished
        - see mk/bulk/do-sandbox-build for examples
        - or maybe 'sandbox' can do it for us
    - create /bulklog, /scratch
    - add pbulk, chown /scratch
    - use "ignore sandbox" option/arg to control whether setup stuff is done
    - summary to stdout / details to a log file
        - show log file path in output/email
* Un-mount the sandbox
    - after the chroot phase
    - error in chroot phase should still unmount sandbox before exiting
    - obey "ignore sandbox" option/arg
* Install pbulk
    - during chroot setup phase
    - remove ok pkg_bulk dir if one is there
    - bootstrap pkg_bulk dir
    - configure pbulk mk.conf to use system-wide work and output dirs
    - clean, build and install pbulk into prepared dir
* Option and command-arg to skip installing pbulk
    - in case you know the one there is still OK
* Configure pbulk
    - during chroot setup phase
    - obey "install pbulk" option/arg
    - expose some things as config options:
        - reuse_scan_results (yes)
        - report_recipients (root)
        - report_subject_prefix (pkgsrc bulk build)
        - make (/usr/bin/make)
        - ulimit -t (1800)
        - ulimit -v (2097152)
        - package list location (/etc/pkglist)
    - make sure to set/obey config options like the pkgsrc location
    - make sure to set/obey system options like the packages directory
        - see mksandbox for examples
* Configure mk.conf
    - during chroot setup phase
    - obey the "ignore sandbox" option
    - set an environment variable that lets the user have pbulk-specific stuff in their system (and chroot) /etc/mk.conf
        - that way they can set e.g. MAKE_JOBS in the "normal" place
        - if MAKE_JOBS isn't set, suggest it
    - set WRKOBJDIR and NO_MULTI_PKG
    - let the rest just pass through
* Sort out wget or curl
    - after installing pbulk, before configuring pbulk or mk.conf
    - obey "skip installing pbulk" option/arg
    - install into the pkg_bulk tree, same as pbulk
    - configure sandbox's /etc/mk.conf with TOOLS_PLATFORM.curl
* Run the build
    - after all the other setup
    - summary to screen, details to log
    - add something to outer log referencing inner log
* Clean up after build
    - after the build, whether it succeeds or fails
        - but still exit with the right code
    - figure out what junk is left behind and delete it
        - maybe wait until sandbox is unmounted?
* Option and command-arg to retry / continue / do a quick build
    - auto-set all the 'skip' options
    - do a manual 'scan' and 'build'
        - or use one of the other wrapper scripts?
* Option and command-arg to set nice level
    - default 10
* Command-arg to get command-arg help

## Install Backlog
TBD

## Later Backlog
* Figure out ccache
* Figure out devel/cpuflags
* rsync pbulk reports to somewhere web-accessible; include that in the output / email
* Remember to use RCD_SCRIPTS_DIR for checking for rc.d scripts
