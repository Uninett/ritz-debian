#!/store/bin/scotty

# $Id$

# Script to monitor/log the software versions and the restart
# reasons (for Cisco routers).

mib load rfc1213.mib
mib load cisco.mib

source "../common/util.tcl"
source "../common/conffile.tcl"
source "../common/polljob.tcl"
source "../common/config.tcl"

proc initDev { sh } {
    global uptime

    set uptime($sh) 0
}

proc pollDev { sh } {
    global uptimeList

    set code [catch {$sh get $uptimeList [list routerUpTime %S %E %V]} result]
}

proc destroyDev { sh } {
    global uptime

    unset uptime($sh)
}

proc expectedUptime { sh newup } {
    global uptime lastpoll uptimeSlop

    set estup [expr $uptime($sh) + \
	    100 * ( [clock seconds] - $lastpoll($sh) ) ]

    if { $uptime($sh) == 0 } { return 0; }
    if { $newup < $estup - $uptimeSlop } { return 0; }
    return 1;
}

proc whyReload { sh {err "unknown error"} {reason "no idea"}} {
    variable ::polljob::cx

    if { $err == "noError" } {
	set res [lindex $reason 2]
	logMsg "$::polljob::cx($sh,name) restart reason" $res
    } else {
	logMsg "$::polljob::cx($sh,name" "whyReload poll returned $err"
    }
}

proc pollCisco { sh } {
    global ciscoList

    set code [catch {$sh get $ciscoList [list whyReload %S %E %V]} res]
    if ($code) {
	logMsg $::polljob::cx($sh,name) $res
    }
}

proc devDescr { sh {err "unknown error"} {objid ""} {descr ""}} {
    variable ::polljob::cx
    global ciscoOidPrefix

    if { $err == "noError" } {
	set descr [lindex $descr 2]
	logMsg "$cx($sh,name) software" $descr

	set oid [mib oid [lindex $objid 2]]
	if {[string first $ciscoOidPrefix $oid] == 0} { # A cisco?
	    pollCisco $sh
	}
    } else {
	logMsg $::polljob::cx($sh,name) "poll returned $err"
    }
}

proc pollOidDescr { sh } {
    global oidDescrList
    variable ::polljob::cx

    set code [catch {$sh get $oidDescrList [list devDescr %S %E %V]} res]
    if ($code) {
	logMsg $::polljob::cx($sh,name) $res
    }
}

proc devUpTime { sh {err "unknown error"} {upt ""}} {
    variable ::polljob::cx
    global uptime lastpoll

    if { $err == "noError" } {
	set up [lindex $upt 2]
	set newUpTime [mib scan [lindex $upt 0] $up]
	if { ! [expectedUptime $sh $newUpTime] } {
	    logMsg "$::polljob::cx($sh,name) reloaded" [whenReload $newUpTime]
	    logMsg "$::polljob::cx($sh,name) uptime" $up
	    pollOidDescr $sh
	}
	set uptime($sh) $newUpTime
	set lastpoll($sh) [clock seconds]
    } else {
	logMsg $::polljob::cx($sh,name) "uptime poll returned $err"
    }
}

proc initPoller {} {
    global uptimeList
    global oidDescrList
    global ciscoOidPrefix
    global ciscoList

    set uptimeList [mib oid sysUpTime.0]
    set oidDescrList [list \
	    [mib oid sysObjectID.0] \
	    [mib oid sysDescr.0]]
    set ciscoOidPrefix [format "%s." [mib oid cisco]]
    set ciscoList [mib oid whyReload.0]
}

set conffile "../test/routers.cf"
::conffile::setHandler ::config::handleChangedConf
::conffile::startCheckJob $conffile 30
