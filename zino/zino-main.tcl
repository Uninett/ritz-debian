#
# $Id$
#

#
# Main program of the zino status monitor.
#

namespace import ::polljob::handle ::polljob::name

#
# Upcalls from config/polljob machinery
#

proc initDev { sh } {

    # Empty
}

proc pollDev { sh } {

    schedPollRouter $sh
}

proc destroyDev { sh } {
    
    cleanupDBvars [name $sh]
}

#
# Main program
#

source "zino.cf"

::persist::setup $persist_file
::persist::restore

initAgent
initEvent $eventid_file $old_events
initFlaps
initStatus

::conffile::startCheckJob $pollfile $conf_check

::persist::startPeriodicDump $persist_period

initAuth $zino_secrets

#
initTrap
