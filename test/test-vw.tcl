#!/store/bin/scotty

# $Id$

# Test script for version monitor

source "../common/util.tcl"
source "../common/conffile.tcl"
source "../common/polljob.tcl"
source "../common/config.tcl"

source "../vwatch/vwatch.tcl"

set conffile "routers.cf"
set dev_descr_dir "dsc"
set logFile "log/events"
set uptimeSlop [expr 100 * 60 * 5]; # 5 minutes

initPoller
::conffile::startCheckJob $conffile 30
