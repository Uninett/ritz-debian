#!/store/bin/scotty

# $Id$

# Test rig for polljob module and config file parsing & handling

source "../common/util.tcl"
source "../common/conffile.tcl"
source "../common/polljob.tcl"
source "../common/config.tcl"

namespace import ::polljob::name

proc initDev { sh } {

    puts [format "initDev %s" [name $sh]]
}

proc pollDev { sh } {

    puts [format "pollDev %s" [name $sh]]
}

proc destroyDev { sh } {

    puts [format "destroyDev %s" [name $sh]]
}

set conffile "routers.cf"

::conffile::startCheckJob $conffile 30
