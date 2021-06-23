#/usr/pkg/bin/scotty
#
# $Id$
#

source load-mibs.tcl

proc secsToStamp { secs } {
    return [clock format $secs -format "%a %b %d %H:%M:%S %Y"]
}

proc getStamp {} {
    return [secsToStamp [clock seconds]]
}

proc log_str { str } {
    set stamp [getStamp]
    return [format "%s: %s" $stamp $str]
}

set log_chans(stdout) 1

proc log { str } {
    global log_chans

    foreach chan [array names log_chans] {
        if { [catch { puts $chan [log_str $str] }] } {
            unset log_chans($chan)
            catch { close $chan }
            log [format "Closed log channel %s" $chan]
        }
    }
}

#source log.tcl
source ../common/persist.tcl
source pm.tcl
source read-cf.tcl
source status.tcl
source swalk.tcl
source trap.tcl
source utils.tcl
source flaps.tcl

source ../common/util.tcl
# source ../common/polljob.tcl

source "zino.cf"

puts "reading config file"
readCf "/a/traffic/conf/polldevs.cf"

namespace eval ::pm { }

::persist::setup "/a/traffic/zino/save-state.tcl"
::persist::restore

proc name { sh } {
    variable cx
    return $cx($sh,name)
}

proc handle { dev } {
    variable cx
    return $cx($dev,handle)
}

proc eventIxExists { args } {
    return 0
}

proc linkTrans { args } {
    return 0
}

foreach r [array names Address] {
    set h [snmp session -address $Address($r) -version SNMPv2c]
    set cx($r,handle) $h
    set cx($h,name) $r
}

set r $AddrToRouter(128.39.0.28)
set h [handle $r]

puts "listening for traps"
set s [snmp session]
$s bind {} trap { doTrap %A %T %V }
