#/store/bin/scotty
#
# $Id$
#

source load-mibs.tcl
source log.tcl
source read-cf.tcl
source status.tcl
source swalk.tcl
source trap.tcl
source utils.tcl
source flaps.tcl

puts "reading config file"
readCf "routers.cf"
puts "setting up handles"
setupHandles
puts "getting addresses"
recordAllAddrs

puts "listening for traps"
set s [snmp session]
$s bind {} trap { doTrap %A %T %V }
