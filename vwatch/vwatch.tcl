#!/local/bin/scotty

# $Id$

# Script to monitor/log the software versions and the restart
# reasons (for Cisco routers).  Config file format understood is
# the same as UNINETTs traffic poller.

#
# Load the standard rfc1213.mib as well as the cisco.mib.  We need the 
# cisco.mib in order to fetch the whyReload variable.  More about this
# later on.
mib load rfc1213.mib
mib load cisco.mib

#
# Handle configuration file.
#
proc readConfig { fileName } {
    global router_address

    set f [open $fileName]
    set inside 0

    while {[gets $f line] >= 0} {
	if { $inside == 0 } {
	    if {[regexp -nocase "router +(\[a-z0-9-\]+) *\{" \
		    $line whole router]} {
		set inside 1
	    }
	} else {
	    if {[regexp -nocase "polladdr *(\[0-9.\]+);" $line whole raddr]} {
		set router_address($router) $raddr
#		puts "$router $raddr"
	    } elseif [regexp "\};" $line] {
		set inside 0
	    }
	}
    }
}

#
# Get a implicit local time stamp, date-like format without time zone
#
proc cleanDate {date} {
    if {[llength $date] == 7} {
	set stamp [lreplace $date 4 5]
    } else {
	set stamp [lreplace $date 4 4]
    }
    return $stamp
}

proc getStamp {} {
    return [cleanDate [getdate]]
}

#
# log a message -- lead-text + value (possibly multi-line, possibly empty)
#
proc logMsg { lead_text { value "" }} {
    global logFile
    set stamp [getStamp]
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
# SNMP request and continuation functions.
#
proc whyReload { sh {err "unknown error"} {reason "no idea"}} {
    global cx
    
    if { [string compare $err "noError"] == 0} {
	set res [lindex $reason 2]
	logMsg "$cx(name,$sh) restart reason" $res
    } else {
	logMsg "$cx(name,$sh)" "whyReload poll returned $err"
    }
}

proc rtr_descr_file sh {
    global cx rtr_descr_dir

    return [format "%s/%s" $rtr_descr_dir $cx(name,$sh)]
}

proc stash_routerDescr {sh {err "uknown error"} {objid ""} {descr ""}} {
    global cx rtr_dir

    if { [string compare $err "noError"] == 0 } {
	set rtr_file [rtr_descr_file $sh]
	if { [catch { set fh [open $rtr_file "w"] } err] == 1 } {
	    logMsg $cx(name,$sh) [format "%s: %s" "desc-file open" $err]
	    return;
	}
	set descr [lindex $descr 2]
	puts $fh $descr
	close $fh
    }
}

proc routerDescr {sh {err "unknown error"} {objid ""} {descr ""}} {
    global cx varCisco ciscoPrefix callBackCisco

    if { [string compare $err "noError"] == 0 } {
	set descr [lindex $descr 2]
	logMsg "$cx(name,$sh) software" $descr

	set oid [mib oid [lindex $objid 2]]
	if {[string first $ciscoPrefix $oid] == 0} { # A cisco?
	    set code [catch {$sh get $varCisco $callBackCisco} result]
	    if ($code) {
		logMsg $cx(name,$sh) $result
	    }
	}
    } else {
	logMsg $cx(name,$sh) "poll returned $err"
    }
}

proc whenReload {uptime} {
    set now [getclock]
    set then [expr $now - $uptime / 100]
    return [cleanDate [getdate $then]]
}

proc routerUpTime {sh {err "unknown error"} {upt ""}} {
    global cx uptime oid_descr_varList oid_descr_callBackStr uptimeSlop

    if { [string compare $err "noError"] == 0 } {
	set up [lindex $upt 2]
	set newUpTime [mib scan [lindex $upt 0] $up]
	set estUpTime [expr $uptime($sh) + \
		100 * ( [getclock] - $cx(lastpoll,$sh) ) ]
	if { $newUpTime < $estUpTime - $uptimeSlop || \
		$uptime($sh) == 0 } {
	    set code [catch \
		    {$sh get $oid_descr_varList $oid_descr_callBackStr} \
		    result]
	    if ($code) {
		logMsg $cx(name,$sh) $result
	    }
	    logMsg "$cx(name,$sh) reloaded" [whenReload $newUpTime]
	    logMsg "$cx(name,$sh) uptime" $up
	}
	set uptime($sh) $newUpTime
	set cx(lastpoll,$sh) [getclock]
#	puts "$cx(name,$sh) $up"

	# Check for router description file, create if not there
	# This is to have all versions easily accessible
	set rtr_file [rtr_descr_file $sh]
	set exists [file exists $rtr_file]
	if { $exists } {
	    file stat $rtr_file st
	}
	if { [expr ! $exists] || $st(size) == 0 } {
	    set code [catch \
		    {$sh get $oid_descr_varList "stash_routerDescr %S %E %V"}]
	}
    } else {
	logMsg $cx(name,$sh) "uptime poll returned $err"
    }
}

proc uptime_check sh {
    global cx uptimeList uptimeCallBackStr
    
#    puts "polling router $cx(name,$sh) ($cx(ip,$sh))"
    set code [catch {$sh get $uptimeList $uptimeCallBackStr} result]
    if ($code) {
#	puts "poll router $cx(name,$sh) ($cx(ip,$sh)) failed ($result)"
    }
}


proc schedulePoll snmph {
    global period cx
#    puts "Scheduling poll of $cx(name,$snmph)"
    job create -interval $period -command [list uptime_check $snmph]
}


proc scheduleAll { } {
    global schedulingNow period cx uptime router_address

    if $schedulingNow { return }
    set schedulingNow 1

#   puts "Scheduling new jobs"

    set nrouters [array size router_address]
    set interval [expr $period/$nrouters]
    set delta 0
    foreach router [array names router_address] {
	set name $router
	set ip   $router_address($router)
	
	set code [catch {snmp session -address $ip -community public} s]
	if {$code} {
	    puts "snmp session failed for router $name"
	    exit
	}
	set cx(ip,$s) $ip
	set cx(name,$s) $name
	set cx(lastpoll,$s) 0
	set uptime($s) 0
#	puts "after $delta \"schedulePoll $s\""
	after $delta "schedulePoll $s"
	set delta [expr $delta+$interval]
    }
    set schedulingNow 0
}

proc checkConfFile { } {
    global confCheckJob logCheckJob confFile lastMod router_address

    file stat $confFile st
    if { $lastMod == 0 } {
	set lastMod $st(mtime)
	return
    }
    if { $st(mtime) != $lastMod } {
#	puts "Config file modified, rescheduling all jobs"

	set lastMod $st(mtime)
	unset router_address
	readConfig $confFile
	# kill active jobs except $checkJob
	foreach job [job info] {
	    if { $job != $confCheckJob && $job != $logCheckJob } {
		$job destroy
	    }
	}
	# Reschedule all jobs after new config file read above
	scheduleAll
    }
}

proc checkLogFile { } {
    global logFile uptime lastSize

#   puts "checking log file"
    set exists [file exists $logFile]
    if { $exists } {
	file stat $logFile st
    }
    if { [expr ! $exists ] \
	    || $st(size) == 0 \
	    || $st(size) < $lastSize } {# if nonexistent, empty or "shrinking"
#	puts "resetting uptime array"
	foreach sh [array names uptime] {
	    set uptime($sh) 0; # reset so that new entries will be logged
	}
    }
    if { [expr ! $exists] } {
	set lastSize 0
    } else {
	set lastSize $st(size)
    }
}

proc scheduleCheckJobs {} {
    global confCheckJob logCheckJob period

    set confCheckJob [job create -interval $period -command checkConfFile]
    set logCheckJob [job create -interval $period -command checkLogFile]
}

set schedulingNow 0

source "ver-watch.cf"

readConfig $confFile

# Setup of SNMP variables & call-chains

set uptimeList [mib oid sysUpTime.0]
set uptimeCallBackStr [list routerUpTime %S %E %V]

set oid_descr_varList [list \
	[mib oid sysObjectID.0] \
	[mib oid sysDescr.0] \
]
set oid_descr_callBackStr [list routerDescr %S %E %V]

set ciscoPrefix [mib oid cisco]
set ciscoPrefix "$ciscoPrefix."

set varCisco [mib oid whyReload.0]
set callBackCisco [list whyReload %S %E %V]

# Start the show

scheduleAll

set lastMod 0
set lastSize 0

scheduleCheckJobs

job wait
