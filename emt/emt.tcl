#
# $Id$
#

#
# E-mail trigger client.
# Sends e-mail notification on "significant events".
#

package require Tnm

mib load rfc1213.mib

set emt_mail "/usr/sbin/sendmail -oi"

proc emt_main {} {
    global emt_to emt_from

    foreach f "~/.ritz.tcl ~/.emt.tcl" {
	if { [file exists $f] } {
	    source $f
	}
    }

    if [info exists AllowClearTextAuth] {
	set ::auth::AllowClearTextAuth $AllowClearTextAuth
    }

    ::persist::setup "emt-save.tcl"
    ::persist::restore
    ::persist::startPeriodicCheckpoint 5;# minutes

    ::persist::add state
    ::persist::add nagged
    ::persist::add history
    ::persist::add log

    emt_loop $Server $Port $User $Secret
}

proc emt_loop { server port user secret } {
    global emt_continue

    while { 1 } {
	emt_open $server $port $user $secret
	emt_init
	emt_check_all
	if [info exists emk_job] {
	    catch { $emk_job destroy }
	}
	set emk_job [job create \
		-interval [expr 5 * 60 * 1000] \
		-command emt_keepalive]

	vwait emt_continue
    }
}

proc emt_notify { what id } {
    global emt_continue

    log [format "notified on %s, type %s" $id $what]

    switch -exact $what {
	State {
	    emt_delay 10 [list emt_delay_check $id]
	}
	Attr {
	    emt_delay 10 [list emt_delay_check $id]
	}
	History {
	    emt_delay 10 [list emt_newhist $id]
	}
	Log {
	    emt_delay 10 [list emt_newlog $id]
	}
	Scavenged {
	    emt_forget $id
	}
	LostConn {
	    set emt_continue 1
	}
    }
}

proc emt_delay { secs cmd } {

    after cancel $cmd
    after [expr $secs * 1000] $cmd
}

proc emt_delay_check { id } {

    ::cp::getAttrs $id
    after [expr 300 * 1000] emt_check_all
}

proc emt_should_report { id } {
    global state nagged

    set os [::attr::getOperState $id]
    if { [::attr::isUpState $os] && [info exists nagged($id)] } {
	return 1
    } elseif { [::attr::isDownState $os] } {
	if { $state($id) != $os } {
	    if { [expr [clock seconds] - [::attr::get $id "updated"]] > 300 } {
		if { ! [info exists nagged($id)] } {
		    return 1
		}
	    } else {
		emt_delay_check $id
	    }
	}
    } else {
	set state($id) $os
	::persist::add state
    }
    return 0
}

# pretty-printed delta time

proc pdt { secs } {

    return [mib format sysUpTime [expr $secs * 100]]
}

proc report_multi { ids } {

    if { [llength $ids] <= 3 } {
	set rr report_single
    } else {
	set rr report_compact
    }
    set rs ""
    foreach id $ids {
	set rs [format "%s%s\n" $rs [$rr $id]]
    }
    return $rs
}

proc report_compact_port { id } {

    set r [::attr::get $id "router"]
    set p [::attr::get $id "port"]
    set d [::attr::get $id "descr"]
    set s [::attr::get $id "portstate"]

    return [format "%s %s (%s) is %s" $r $p $d $s]
}

proc report_compact_reach { id } {
    
    set r  [::attr::get $id "router"]
    set rs [::attr::get $id "reachability"]

    return [format "%s %s" $r $rs]
}

proc report_compact { id } {

    set type [::attr::get $id "type"]
    switch -exact $type {
	portstate {
	    return [report_compact_port $id]
	}
	reachability {
	    return [report_compact_reach $id]
	}
	default {
	    puts stderr "Unknown type: $type for id $id"
	    return 0
	}
    }
}

proc report_single_port { id } {

    set ps [::attr::get $id "portstate"]
    set rs [format   "      router: %s\n"     [::attr::get $id "router"]]
    set rs [format "%s        port: %s\n" $rs [::attr::get $id "port"]]
    set rs [format "%s       descr: %s\n" $rs [::attr::get $id "descr"]]
    set rs [format "%s   portstate: %s\n" $rs $ps]
    set rs [format "%s  case-state: %s\n" $rs [::attr::get $id "state"]]
    if [::attr::isDownState $ps] {
	set rs [format "%s        down: %s\n" $rs [pdt [::attr::downtime $id]]]
	set rs [format "%s      reason: %s\n" $rs [::attr::get $id "reason"]]
    }
#    set rs [format "%s\n" $rs]

    return $rs
}

proc report_single_reach { id } {

    set rs [format   "      router: %s\n"     [::attr::get $id "router"]]
    set r [::attr::get $id "reachability"]
    set rs [format "%sreachability: %s\n" $rs $r]
    set rs [format "%s  case-state: %s\n" $rs [::attr::get $id "state"]]
    if [::attr::isDownState $r] {
	set rs [format "%s        down: %s\n" $rs [pdt [::attr::downtime $id]]]
    }
#    set rs [format "%s\n" $rs]

    return $rs
}

proc report_single { id } {

    set type [::attr::get $id "type"]
    switch -exact $type {
	portstate {
	    return [report_single_port $id]
	}
	reachability {
	    return [report_single_reach $id]
	}
	default {
	    puts stderr "Unknown type: $type for id $id"
	    return 0
	}
    }
}

proc multi_subject { ids } {

    return [format "Outage report (%d events)" [llength $ids]]
}

proc single_subject { id } {

    return [report_compact $id]
}

proc emt_format_mail { subject body } {
    global emt_to emt_from emt_mail

    set m   [format "To: %s\n" $emt_to]
    set m [format "%sFrom: %s\n" $m $emt_from]
    set m [format "%sSubject: %s\n\n" $m $subject]
    set m [format "%s%s\n" $m $body]
    return $m
}

proc emt_mail { subject body } {
    global emt_to emt_mail

    set fd [open [format "|%s %s" $emt_mail $emt_to] "w"]
    set mail [emt_format_mail $subject $body]
    puts $fd $mail
    close $fd

    log [format "Sent message:\n%s" $mail]
}

proc emt_report { ids } {
    global nagged

    if { [llength $ids] > 1 } {
	set sids [::sort::sortCases $ids]
	set body [report_multi $sids]
	set subject [multi_subject $sids]
    } else {
	set body [report_single $ids]
	set subject [single_subject $ids]
    }
    emt_mail $subject $body
    foreach id $ids {
	set nagged($id) 1
    }
    ::persist::add nagged
}

proc emt_check_all {} {
    global state

    log [format "Checking all events"]

    set rids ""
    foreach id [array names state] {
	if [emt_should_report $id] {
	    lappend rids $id
	}
    }
    if { [llength $rids] != 0 } {
	emt_report $rids
    }
}

proc emt_init {} {
    global state
    
    set ids [::cp::pullCases]
    foreach id $ids {
	set sid($id) 1
	if { ! [info exists state($id)] } {
	    set state($id) "unknown"
	}
	emt_gethist $id
#	emt_getlog $id
    }
    ::persist::add history
#    ::persist::add log

    foreach id [array names state] {
	if { ! [info exists sid($id)] } {
	    emt_forget $id
	}
    }
}

proc emt_newhist { id } {
    global history
    
    set new [::cp::getHist $id]
    set ol [string length $history($id)]
    set history($id) $new
    return [string range $new $ol end]
}

proc emt_gethist { id } {
    global history

    set history($id) [::cp::getHist $id]
}

proc emt_newlog { id } {
    global log

    set ol 0
    catch { set ol [string length $log($id)] }
    set new [emt_getlog $id]
    return [string range $new $ol end]
}

proc emt_getlog { id } {
    global log

    set log($id) [::cp::getLog $id]
}

proc emt_forget { id } {

    foreach a "log history state nagged" {
	global $a
	catch { unset [set a]($id) }
    }
}

# Robust open, sleeps and retries if required

proc emt_open { server port user secret } {
    global errorInfo

    while [catch {
	::net::close
	::net::open $server $port
	::auth::login $user $secret
	::notify::open emt_notify
    } msg ] {
	puts stderr [format "Error opening server %s: %s" $server $msg]
	puts stderr [format "%s" $errorInfo]
	after [expr 60 * 1000]
    }
}

# Periodically "ping" the other end to see that we get a response

proc emt_keepalive {} {
    global emt_continue
    global state

    log [format "Keepalive running"]

    set ids [array names state]
    if {[llength $ids] > 0} {
	set id [lindex $ids 0]
    } else {
	set id 1;		# dummy ID, don't care about response,
				# just that we get one.
    }

    if [catch { ::cp::getAttrs $id } msg] {
	if [regexp "lost connection" $msg] {
	    log [format "Keepalive failed, reopening: %s" $msg]
	    set emt_continue 1
	}
    }
}

proc log { str } {

    puts [format "%s: %s" [clock format [clock seconds]] $str]
}
