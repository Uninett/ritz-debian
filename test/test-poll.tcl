#!/store/bin/scotty

# $Id$

# Test rig for polljob module and config file parsing & handling

source "../common/util.tcl"
source "../common/conffile.tcl"
source "../common/polljob.tcl"
source "../common/config.tcl"

namespace import ::polljob::cx

proc initDev { sh } {

    puts [format "initDev %s" [cx $sh name]]
}

proc pollDev { sh } {

    puts [format "pollDev %s" [cx $sh name]]
}

proc destroyDev { sh } {

    puts [format "destroyDev %s" [cx $sh name]]
}

set conffile "routers.cf"

::conffile::setHandler ::config::handleChangedConf
::conffile::startCheckJob $conffile 30
