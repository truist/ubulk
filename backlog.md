# ubulk dev backlog

## Done

* Do a manual bulk build with pbulk
* Do a scripted install of all desired packages
* Make a backlog

## Build Backlog

* Formal script that can update pkgsrc
    - config file with pkgsrc dir (/usr/pkgsrc)
        - command-arg to override default config location (/etc/ubulk.conf)
    - git-only
    - die on error
* Log results and be ready to be run from cron
    - config log file (/var/log/ubulk-build.log)
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
* Formal script that can install chosen packages
    - reuse config file from build script
        - command arg to override config file location
    - die on error
    - map chosen package names to package files (die on mismatch)
    - install all the packages, recording result of each, but waiting until the end to exit
    - no handling of old packages and/or rc.d stuff, yet
* Log results and be ready to be run from cron
    - config log file (/var/log/ubulk-install.log)
    - summary to stdout / details to log file
    - output path to log file
* Delete old packages before install
    - after checking that package files all match
    - delete everything installed in the system
    - on error, die with comprehensive error message
* Option and command-arg to skip deletion (and just do install)
    - e.g. if you had a prior delete fail, and manually finished it
* Check if expected packages are actually installed
    - i.e. maybe they reported "success" but aren't really there
    - at the very end of the script (even after later stories)
    - output any differences
    - if differences, exit with error code
* Stop all pkgsrc-based services
    - before deleting all the packages
    - Remember to use RCD_SCRIPTS_DIR for checking for rc.d scripts
    - figure out which packages to stop, based on installed package list
    - stop them in reverse-dependency order
    - report failed stops
    - config option to continue or stop after failed stop (continue)
    - don't worry about restarting them, yet
* Option and command-arg to ignore services
    - e.g. if you want to manually stop and start them
* Start old services again
    - after successful install
    - obey config option
    - only start the ones that were stopped
    - report failed starts
    - config option to continue or stop after failed start (continue)
    - report missing rc.d scripts
    - config option to continue or stop after missing script (continue)
* Show log output during startup
    - start recording output before starting services
    - report output after services started
    - ignore errors
* Option and command-arg to skip log reporting
    - e.g. if you have other monitoring techniques

## Fancy side-by-side install

    # Create a "build" user with permissions to sudo root without a password.
    # Put your pkgsrc tree in there.
    # Take my config files: /etc/mk.conf, /etc/pkgsrc/mk.conf, ~build/pkg_comp  /default.conf, and populate your own /etc/pkgsrc/pkglist
    # bootstrap, if needed:
        $ VINTAGE=20130608
        $ sudo ./bootstrap --prefix /usr/.pkg-${VINTAGE} --pkgdbdir /usr/.pkg-${VINTAGE}/.pkgdb --sysconfdir /etc/pkg --varbase /var/pkg
    # Build your first full batch of schmonzified packages: as build, with VINTAGE set how you want, "sudo pkg_comp auto 2>&1 | tee build.log"
    # cd binaries/packages/${VINTAGE}/All
    # pkg_add -K /usr/.pkg-${VINTAGE}/.pkgdb pkg_install*.tgz | tee ~build/install.log
    # /usr/.pkg-${VINTAGE}/sbin/pkg_add *.tgz | tee -a ~build/install.log
    # XXX diff for changes I'd want to make to /etc files
    # XXX make sure mail queue is empty (any other queues?)
    # /etc/rc.d/{dovecot,mysqld,php_fpm,apache,qmailqread,qmailsend} stop
    # rm /usr/pkg && ln -s /usr/.pkg-${VINTAGE} /usr/pkg
    # /etc/rc.d/{qmailsend,qmailqread,apache,php_fpm,mysqld,dovecot} start
    # cd .../pkgtools/pkg_rolling-replace && make install clean
    # chmod 755 /usr/sbin/pkg_* && cd .../pkgtools/pkg_install && make install clean && sudo chmod 0 /usr/sbin/pkg_* /usr/sbin/audit-packages /usr/sbin/down  load-vulnerability-list
    # have fun
    # pkg_comp again later
    # update the /usr/pkg symlink

It needs this mk.conf:

    # settings common to all pkgsrc builds, whether done by
    # - pkg_comp(8) (which defines a new date-based VINTAGE)
    # - a one-off built directly in pkgsrc
    
    _LOGICALBASE=           /usr/pkg                # symlink points to LOCALBASE
    _LOCALPATH=             /usr/.pkg-              # LOCALBASE is here somewhere
    
    .if !defined(VINTAGE)
    VINTAGE!=               ( readlink -f ${_LOGICALBASE} \
                                | sed -e 's|^${_LOCALPATH}||' )
    .endif
    
    _PHYSICALBASE=          ${_LOCALPATH}${VINTAGE}
    LOCALBASE=              ${_PHYSICALBASE}
    
    PKG_DBDIR=              ${LOCALBASE}/.pkgdb


(which should be supplied as a referencable snippet)

## Later Backlog
* Figure out ccache
* Figure out devel/cpuflags
* rsync pbulk reports to somewhere web-accessible; include that in the output / email
