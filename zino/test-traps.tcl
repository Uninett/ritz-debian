#/usr/pkg/bin/scotty
#
# $Id$
#

source load-mibs.tcl
source log.tcl
source ../common/persist.tcl
source pm.tcl
source read-cf.tcl
source status.tcl
source swalk.tcl
source trap.tcl
source utils.tcl
source flaps.tcl

source "zino.cf"

puts "reading config file"
readCf "polldevs.cf"

::persist::setup "/data/traffic/zino/save-state.tcl"
::persist::restore

puts "listening for traps"
set s [snmp session]
$s bind {} trap { doTrap %A %T %V }
