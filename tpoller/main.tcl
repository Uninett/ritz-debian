#
# $Id$
#

set conffile "%CONFIGDIR%/polldevs.cf"
set uptimeSlop [expr 100 * 60 * 3]; # 3 minutes
set LogDir "%DATADIR%/today"

::conffile::startCheckJob $conffile 120
