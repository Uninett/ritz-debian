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

namespace import ::polljob::cx

#
# Polljob upcalls
#

proc initDev { sh } {
    global uptime

    set uptime($sh) 0
}

proc pollDev { sh } {
    global uptimeList

    set code [catch {$sh get $uptimeList [list devUpTime %S %E %V]} result]
}

proc destroyDev { sh } {
    global uptime

    unset uptime($sh)
}

#
# A few utility functions
#

# Get a implicit local time stamp, date-like format without time zone

proc getDate { secs } {
    return [clock format $secs -format "%a %b %d %H:%M:%S %Y"]
}

proc dev_descr_file sh {
    global dev_descr_dir

    return [format "%s/%s" $dev_descr_dir [cx $sh name]]
}

#
# log a message -- lead-text + value (possibly multi-line, possibly empty)
#
proc logMsg { lead_text { value "" }} {
    global logFile

    set stamp [getDate [clock seconds]]
    set logf [open $logFile "a"]
    if {[regexp "\n" $value]} {
	puts $logf [format "%s  %s: #\n%s\n#" $stamp $lead_text $value]
    } elseif {! [regexp "^$" $value]} {
	puts $logf [format "%s  %s: %s" $stamp $lead_text $value]
    } else {
	puts $logf [format "%s  %s" $stamp $lead_text]
    }
    close $logf
}

#
# Polling-related functions
#

proc expectedUptime { sh newup } {
    global uptime lastpoll uptimeSlop

    set estup [expr $uptime($sh) + \
	    100 * ( [clock seconds] - $lastpoll($sh) ) ]

    if { $uptime($sh) == 0 } { return 0; }
    if { $newup < $estup - $uptimeSlop } { return 0; }
    return 1
}

proc whyReload { sh {err "unknown error"} {reason "no idea"}} {

    if { $err == "noError" } {
	set res [lindex $reason 2]
	logMsg [format "%s restart reason" [cx $sh name]] $res
    } else {
	logMsg [cx $sh name] "whyReload poll returned $err"
    }
}

proc pollCisco { sh } {
    global ciscoList

    set code [catch {$sh get $ciscoList [list whyReload %S %E %V]} res]
    if ($code) {
	logMsg [cx $sh name] $res
    }
}

proc devDescr { sh {err "unknown error"} {objid ""} {descr ""}} {
    global ciscoOidPrefix

    if { $err == "noError" } {
	set descr [lindex $descr 2]
	logMsg [format "%s software" [cx $sh name]] $descr

	set oid [mib oid [lindex $objid 2]]
	if {[string first $ciscoOidPrefix $oid] == 0} { # A cisco?
	    pollCisco $sh
	}
    } else {
	logMsg [cx $sh name] "poll returned $err"
    }
}

proc pollOidDescr { sh } {
    global oidDescrList

    set code [catch {$sh get $oidDescrList [list devDescr %S %E %V]} res]
    if ($code) {
	logMsg [cx $sh name] $res
    }
}

proc saveDescr { sh {err "unknown error"} {objid ""} {descr ""}} {

    if { [string compare $err "noError"] == 0 } {
	set f [dev_descr_file $sh]
	if { [catch { set fh [open $f "w"] } err] == 1 } {
	    logMsg [cx $sh name] "desc-file open: $err"
	    return
	}
	set descr [lindex $descr 2]
	puts $fh $descr
	close $fh
    }
}

proc maybeSaveDescr { sh } {
    global oidDescrList

    set f [dev_descr_file $sh]
    set exists [file exists $f]
    if { $exists } {
	file stat $f st
    }
    if { [expr ! $exists] || $st(size) == 0 } {
	catch {$sh get $oidDescrList [list saveDescr %S %E %V]}
    }
}

proc devUpTime { sh {err "unknown error"} {upt ""}} {
    global uptime lastpoll

    if { $err == "noError" } {
	set up [lindex $upt 2]
	set newUpTime [mib scan [lindex $upt 0] $up]
	if { ! [expectedUptime $sh $newUpTime] } {
	    logMsg [format "%s reloaded" [cx $sh name]] [whenReload $newUpTime]
	    logMsg [format "%s uptime" [cx $sh name]] $up
	    pollOidDescr $sh
	}
	set uptime($sh) $newUpTime
	set lastpoll($sh) [clock seconds]

	maybeSaveDescr $sh
    } else {
	logMsg [cx $sh name] "uptime poll returned $err"
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
set dev_descr_dir "dsc"; # Needs better configuration
initPoller
::conffile::setHandler ::config::handleChangedConf
# Start the show
::conffile::startCheckJob $conffile 30
