#!/store/bin/scotty
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
source persist.tcl
source events.tcl
source server.tcl
source auth.tcl

puts "reading saved state"
setPersistFile "save-state.tcl"
readPersistVars

initEvent "eventid" "/local/src/zino/old-events/"
initFlaps
initStatus

puts "reading config file"
readCf "routers.cf"
startCfCheckJob "routers.cf" 1

puts "setting up handles"
setupHandles

startPersistJob $DefaultInterval

set authTacacs 1
set Tacping "/local/bin/tacping.pl"
set Tachost "trane.uninett.no"

initAuth "/local/src/zino/zino/secrets"
set authClearTextPasswords 1
set OpenServerAccess 1

puts "starting poller jobs"
startRouterPollJobs

unset NewRouter

puts "listening for traps"
initTrap
