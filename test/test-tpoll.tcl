#!/store/bin/scotty

# $Id$

# Test script for traffic statistics poller

source "../common/util.tcl"
source "../common/conffile.tcl"
source "../common/polljob.tcl"
source "../common/config.tcl"
source "../common/justSNMP.tcl"

source "../tpoller/tpoller.tcl"

set conffile "routers.cf"

set uptimeSlop [expr 100 * 60 * 3]; # 3 minutes
set LogDir "traffic"

::conffile::startCheckJob $conffile 120
