#! %SCOTTY%
#
# $Id$
#

# Version monitor

source "../common/util.tcl"
source "../common/conffile.tcl"
source "../common/polljob.tcl"
source "../common/config.tcl"

set conffile "%CONFDIR%/polldevs.cf"

set vwtop "%TOPDIR%/ver-watch"
set vwtoday [format "%s/%s" $vwtop "logs/today"]

set dev_descr_dir "$vwtoday/descs"
set logFile "$vwtoday/ver-watch.log"
set uptimeSlop [expr 100 * 60 * 5]; # 5 minutes

initPoller
::conffile::startCheckJob $conffile 30
