#
# $Id$
#

catch { namespace delete ::pm }

namespace eval ::pm {

    namespace export add addlog ids details matching cancel log

    global ::pm::lasttime
    if { ! [info exists ::pm::lasttime] } {
	set ::pm::lasttime 0;	# provide an initial value
    }

    after 60000 ::pm::periodic

    ::persist::add ::pm::lasttime
    ::persist::add ::pm::lastid
    ::persist::add ::pm::events
    ::persist::add ::pm::pm_events

    ::persist::after_restore ::pm::restore

    proc restore { } {

	# we need to ensure we continue remembering these
	foreach var [info vars ::pm::event_*] {
	    ::persist::add $var
	}
    }

    proc add { from_t to_t type match_type match_expr match_dev } {

	set id [newid]
	set name [attrs $id]
	global $name
	set [set name](starttime) $from_t
	set [set name](endtime) $to_t
	set [set name](type) $type
	set [set name](match_type) $match_type
	set [set name](match_expr) $match_expr
	set [set name](match_dev) $match_dev

	::persist::add $name
	::persist::dump
	return $id
    }

    proc preplog { entry user } {
	
	regsub -all "^" $entry " " entry
	regsub -all "\n" $entry "\n " entry
	regsub -all "\n \n" $entry "\n\n" entry
	set e [format "%s %s\n%s" [clock seconds] $user $entry]
	return $e
    }

    proc addlog { id text user } {
	
	set text [preplog $text $user]

	set name [attrs $id]
	global $name
	lappend [set name](log) $text
    }

    proc getlog { id } {

	return [attr $id log]
    }

    proc ids { } {
	global ::pm::events

	return [array names ::pm::events]
    }

    proc cancel { id user } {

	::pm::close $id "PM cancelled" user
    }

    proc details { id } {
	# return details for a PM event:
	# $id $from_t $to_t $type $match_type [$match_dev] $match_expr

	set s ""
	set s [format "%d" $id]
	set s [format "%s %s" $s [attr $id starttime]]
	set s [format "%s %s" $s [attr $id endtime]]
	set s [format "%s %s" $s [attr $id type]]
	set mt [attr $id match_type]
	set s [format "%s %s" $s $mt]

	if { $mt == "intf-regexp" } {
	    set s [format "%s %s" $s [attr $id match_dev]]
	}

	set s [format "%s %s" $s [attr $id match_expr]]	       

	return $s
    }

    proc matching { id } {
	# return list of
	#   $id portstate $router $if_index $if_descr ($description)
	# for interfaces affected by a portstate PM, or
	#   $id device $devicename
	# for a PM affecting a router/device

	set rv {}

	set type       [attr $id "type"]
	set match_type [attr $id "match_type"]
	set match_expr [attr $id "match_expr"]
	set match_dev  [attr $id "match_dev"]

	if { $type == "portstate" } {
	    foreach ix [matching_ports $match_type $match_expr $match_dev] {
		global ::portToIfDescr

		set l [split $ix ","]
		set r [lindex $l 0]
		set ifix [lindex $l 1]

		catch { lappend rv [list $id portstate $r $ifix \
					$portToIfDescr($ix) \
					[format "(%s)" [description $ix]]]
		}
	    }
	} elseif { $type == "device" } {
	    foreach dev [matching_devices $match_type $match_expr] {
		lappend rv [list $id device $dev]
	    }
	}
	return $rv
    }

    proc attrs { id } {

	return [format "::pm::event_%d" $id]
    }

    proc attr { id attr } {

	set varname [attrs $id]
	global $varname

	set val ""
	catch { set val [set [set varname]($attr)] }
	return $val
    }

    proc newid { } {
	global ::pm::lastid

	if { [info exists lastid] } {
	    set n [expr $lastid + 1]
	} else {
	    set n 0
	}
	set lastid $n
	set id $n

	# Data structure for PM event
	set name [attrs $id]
	::persist::add $name

	# Add new event to events array
	global ::pm::events
	set ::pm::events($n) 1

	::persist::dump
	return $n
    }

    proc close { id reason user } {
	global ::pm::pm_events

	addlog $id $reason $user

	# Save for posterity
	save $id

	# Delete from events array
	catch { unset ::pm::events($id) }

	# and don't make it persistent anymore
	set name [attrs $id]
	::persist::remove $name

    }

    # not implemented yet
    proc save { id } {
    }

    proc starting_pms { lasttime timenow } {

	set s {}
	foreach id [ids] {
	    set name [attrs $id]
	    global $name
	    set start [set [set name](starttime)]
	    if { $lasttime < $start && $timenow >= $start } {
		lappend s $id
	    }
	}
	return $s
    }

    proc ending_pms { lasttime timenow }  {

	set s {}
	foreach id [ids] {
	    set name [attrs $id]
	    global $name
	    set end [set [set name](endtime)]
	    if { $lasttime < $end && $timenow >= $end } {
		lappend s $id
	    }
	}
	return $s
    }

    proc active_pms { } {

	set s {}
	foreach id [ids] {
	    set name [attrs $id]
	    global $name
	    set end [set [set name](endtime)]
	    set start [set [set name](starttime)]
	    set now [clock seconds]
	    if { $end > $now && $start < $now } {
		lappend s $id
	    }
	}
	return $s
    }

    proc port_matches_pm { ix pmid } {
	global ::portToLocIfDescr

	set match_type [attr $pmid "match_type"]
	set match_expr [attr $pmid "match_expr"]

	if { $match_type == "regexp" } {
	    if [regexp $match_expr $portToLocIfDescr($ix)] {
		return 1
	    }
	} elseif { $match_type == "str" } {
	    if [string match $match_expr $portToLocIfDescr($ix)] {
		return 1
	    }
	}
	return 0
    }

    proc dev_matches_pm { name pmid } {
	# abuse this to get at list of devices
	global ::isCisco

	set match_type [attr $pmid "match_type"]
	set match_expr [attr $pmid "match_expr"]

	if { $match_type == "str" } {
	    foreach {dev val} [array get isCisco $match_expr] {
		return 1
	    }
	} elseif { $match_type == "exact" } {
	    if [info exists isCisco($match_expr)] {
		return 1
	    }
	}
	return 0
    }

    proc pm_matches { pmid eid } {

	set t [getEventAttr $eid "type"]
	set pmt [attr $pmid "type"]

	if { $t == "portstate" && $pmt == "portstate" } {
	    set r [getEventAttr $eid "router"]
	    set ifix [getEventAttr $eid "ifindex"]
	    set ix [format "%s,%s" $r $ifix]
	    if [port_matches_pm $ix $pmid] {
		return 1
	    }
	} elseif { $t == "reachability" && $pmt == "device" } {
	    set r [getEventAttr $eid "router"]
	    if [dev_matches_pm $r $pmid] {
		return 1
	    }
	}
	return 0
    }

    proc check_pm_event { eid } {

	log [format "debug: PM: checking event %d" $eid]

	set t [getEventAttr $eid "type"]
	set s [getEventAttr $eid "state"]

	# if already set to "ignored", don't mess more with it
	if {$s == "ignored"} { return; }
	if {$s == "closed"} { return; }; # ignore these as well...

	foreach pm [active_pms] {
	    if [pm_matches $pm $eid] {
		# set to ignored during PM
		setEventAttr $eid "state" "ignored"
		eventLog $eid \
		    "entered into existing active PM event id $pm"
		eventCommit $eid
		lappend ::pm::pm_events($pm) $eid
	    }
	}
    }

    proc matching_ports { match_type match_expr match_dev } {
	global ::portToLocIfDescr
	global ::portToIfDescr

	set ixes {}
	if { $match_type == "regexp" } {
	    foreach ix [array names portToLocIfDescr] {
		if [regexp $match_expr $portToLocIfDescr($ix)] {
		    lappend ixes $ix
		}
	    }
	} elseif { $match_type == "str" } {
	    foreach ix [array names portToLocIfDescr] {
		if [string match $match_expr $portToLocIfDescr($ix)] {
		    lappend ixes $ix
		}
	    }
	} elseif { $match_type == "intf-regexp" } {
	    # match expression for array get
	    set me [format "%s,*" $match_dev]
	    foreach {ix intf} [array get ::portToIfDescr $me] {
		# make sure it's the right device
		set l [split $ix ","]
		if { [lindex $l 0] != $match_dev } {
		    continue;
		}
		# and match the interface name
		if [regexp $match_expr $intf] {
		    lappend ixes $ix
		}
	    }
	}
	return $ixes
    }

    proc matching_devices { match_type match_expr } {
	# abuse this to get at list of devices
	global ::isCisco

	set devs {}
	if { $match_type == "str" } {
	    foreach {dev val} [array get isCisco $match_expr] {
		lappend devs $dev
	    }
	} elseif { $match_type == "exact" } {
	    if [info exists isCisco($match_expr)] {
		lappend devs $match_expr
	    }
	} elseif { $match_type == "regexp" } {
	    foreach dev [array names isCisco] {
		if [regexp $match_expr $dev] {
		    lappend devs $dev
		}
	    }
	}
	return $devs
    }

    proc start_pm { id } {
	global ::pm::pm_events

	# when a PM period starts, create events for affected
	# interfaces and devices (if events don't already exist), and
	# set them to "ignored" state.

	log [format "debug: PM: starting PM for event %d" $id]

	set name [attrs $id]
	global $name

	set type       [set [set name](type)]
	set match_type [set [set name](match_type)]
	set match_expr [set [set name](match_expr)]
	if [info exists [set name](match_dev)] {
	    set match_dev [set [set name](match_dev)]
	} else {
	    set match_dev ""
	}

	set ::pm::pm_events($id) {}

	if { $type == "portstate" } {
	    global ::portToIfDescr
	    global ::portState
	    set ixes [matching_ports $match_type $match_expr $match_dev]
	    foreach ix $ixes {
		set eid [::eventId $ix "portstate"]
		set l [split $ix ","]
		set r [lindex $l 0]
		set ifix [lindex $l 1]

		if [ catch {
		    set updown $::portState($r,$ifix)
		}] {
		    set updown "up"; # default...
		}

		setEventAttrs $eid \
		    "router" $r \
		    "port" $portToIfDescr($ix) \
		    "portstate" $updown \
		    "ifindex" $ifix \
		    "polladdr" [::config::conf $r address] \
		    "priority" [::config::conf $r priority] \
		    "descr" [description $ix]

		eventLog $eid [getlog $id]
		# get special handling of embyonic -> open transition first
		eventCommit $eid

		# ...and then immediately set to "ignored"
		setEventAttr $eid "state" "ignored"
		eventCommit $eid
		lappend ::pm::pm_events($id) $eid
	    }
	} elseif { $type == "device" } {
	    set devs [matching_devices $match_type $match_expr]
	    foreach dev $devs {
		set rid [::eventId $dev "reachability"]
		set rai [::eventId "$dev,red" "alarm"]
		set yai [::eventId "$dev,yellow" "alarm"]

		foreach eid [list $rid $rai $yai] {
		    setEventAttrs $eid \
			"router" $dev \
			"polladdr" [::config::conf $dev address] \
			"priority" [::config::conf $dev priority]

		    # we assume things about the actual state,
		    # may be auto-corrected by status polling
		    set l ""
		    if {$eid == $rid} {
			setEventAttr $eid "reachability" "reachable"
			set l "assumed reachable"
			set l "$l, planned maintenance starts"
		    } else {
			if {$eid == $rai} {
			    set colour "red"
			} else {
			    set colour "yellow"
			}
			setEventAttr $eid "alarm-type" $colour
			setEventAttr $eid "alarm-count" "0"
			set l "alarm count assumed to be 0"
			set l "$l, planned maintenance starts"
			setEventAttr $eid "lastevent" $l
		    }

		    eventLog $eid $l
		    eventLog $eid [getlog $id]
		    eventCommit $eid

		    setEventAttr $eid "state" "ignored"
		    eventCommit $eid

		    lappend ::pm::pm_events($id) $eid
		}
	    }
	}
    }

    proc end_pm { id } {
	global ::pm::pm_events

	log [format "debug: PM: ending PM id %d" $id]

	# when a PM period ends, take the affected interfaces out of
	# "ignored" state and back into (?) "open" or "closed"(?)
	# state, possibly depending on whether the interface is back
	# up or remains down(?).
	
	# Similar for reachability and alarm PM events

	# For now just set state unconditionally back to "open", and
	# leave the closing of the events to be done manually
	foreach eid $::pm::pm_events($id) {
	    setEventAttr $eid "state" "open"
	    eventCommit $eid
	}

    }

    proc old_pms { now } {
	# return list of PM events which ended more than 72(?) hours ago

	set s {}
	foreach id [ids] {
	    set name [attrs $id]
	    global $name
	    if { [expr $now - 72 * 3600] > [set [set name](endtime)] } {
		lappend s $id
	    }
	}
	return $s
    }

    proc periodic { } {
	global ::pm::lasttime

	set now [clock seconds]

	foreach id [starting_pms $lasttime $now] {
	    if [catch {
		start_pm $id
	    } err] {
		log $err
	    }
	}

	foreach eid [eventIds] {
	    if [catch {
		check_pm_event $eid
	    } err] {
		log $err
	    }
	}

	foreach id [ending_pms $lasttime $now] {
	    if [catch {
		end_pm $id
	    } err] {
		log $err
	    }
	}

	set lasttime $now

	foreach id [old_pms $now] {
	    log [format "debug: PM: cleaning out old PM id %d" $id]
	    ::pm::close $id "timer expiry for old PMs" "zino"
	}

	after 60000 ::pm::periodic
    }

}
