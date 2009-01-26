#
# $Id$
#

# Call this from main program, give name of file where
# the ID of the last assigned event ID should be saved
# and the top directory of the saved/closed events should
# be stored

proc initEvent { saveFile saveDir } {
    global lastEvent
    global eventLogLimit 
    global eventSaveDir
    global EventId
    global eventExpiry
    
    setEventFile $saveFile
    set eventSaveDir $saveDir
    
    restoreLastEvent
    trace variable lastEvent w saveLastEvent
    set eventLogLimit 50
    set eventExpiry [expr 8 * 60 * 60]; # 8 hours

    ::persist::add ::EventId
    ::persist::add ::EventIdToIx
    ::persist::add ::EventCloseTimes

    foreach ix [array names EventId] {
	set e $EventId($ix)
	initEventAttrs $e
    }
#    fixupEventIdToIx
    fixupEventState
}

proc fixupEventState { } {
    global EventState
    global EventId

    foreach ix [array names EventId] {
	set id $EventId($ix)
	if [catch { set state [getEventAttr $id state] } msg] {
	    continue;		# oops
	}
	if { ! [info exists EventState($id)] } {
	    set EventState($id) $state
#	    puts [format "Initializing eventstate for %s to %s" \
#		    $id $state]
	} elseif { $state != $EventState($id) } {
	    set EventState($id) $state
#	    puts [format "Updating eventstate for %s from %s to %s" \
#		    $id $EventState($id) $state]
	}
    }
}

proc initEventAttrs { id } {

    ::persist::add ::EventAttrs_$id
}

proc fixupEventIdToIx { } {
    global EventId
    global EventIdToIx

    foreach ix [array names EventId] {
	set id $EventId($ix)
	if { ! [info exists EventIdToIx($id)] } {
	    puts [format "fixed up %s" $id]
	    set EventIdToIx($id) $ix
	}
    }
}

proc setEventFile { file } {
    global EventIdSaveFile

    set EventIdSaveFile $file
}

proc saveLastEvent { name elt op } {
    global EventIdSaveFile
    upvar $name x

    if { ! [info exists EventIdSaveFile] } { return; }

    set f [open $EventIdSaveFile "w"]
    puts $f $x
    close $f
}

proc restoreLastEvent { } {
    global lastEvent EventIdSaveFile

    if { ! [info exists EventIdSaveFile] } { return; }

    set nc 0
    if { [file exists $EventIdSaveFile] } {
	set f [open $EventIdSaveFile "r"]
	set nc [gets $f lastEvent]
	close $f
    }
    if {$nc < 1} { # Either file doesn't exist or we read 0 chars
	set lastEvent 0
    }
}

proc newEvent { } {
    global lastEvent
    
    set lastEvent [expr $lastEvent + 1]
}

# Is there an open event for this ix?

proc eventIxExists { ix type } {
    global EventId
    return [info exists EventId($ix,$type)]
}

# Is there a closed event for this ix?

proc closedEventIxExists { ix type } {
    global PreClosedEventId

    return [info exists PreClosedEventId($ix,$type)]
}

proc closedEventId { ix type } {
    global PreClosedEventId

    return $PreClosedEventId($ix,$type)
}

# Returns the active event ID for the ix/type pair
# if there is an active event,
# otherwise just return the ID of an embryonic event

proc eventId { ix type } {
    global EventId EventIdToIx

    if { [info exists EventId($ix,$type)] } {
	set id $EventId($ix,$type)
	initEventAttrs $id
	return $id
    }
    set id [newEvent]
    set EventId($ix,$type) $id
    set EventIdToIx($id) [format "%s,%s" $ix $type]
    initEventAttrs $id
    setEventAttr $id type $type
    setEventAttr $id id $id
    setEventAttr $id state "embryonic"
    return $id
}

# Top-level, use this one also to set event state.
# The settings will not take effect before eventCommit is called.

proc setEventAttr { id attr value { user monitor } } {
    set Attrs NewEventAttrs_$id
    global $Attrs
    global EventState
    global eventAttrChange
    
    set oldval ""
    catch { set oldval [getEventAttr $id $attr] }

    if { $attr == "state" } {
	# Additional special handling
	setEventState $id $value $user
    } elseif { $attr != "log" && $attr != "history" } {
	# the "log" and "history" entries are being taken care of separately
	if { $oldval != $value } {
	    set eventAttrChange($id) $attr
	}
    }

    set [set Attrs]($attr) $value
}

# Commit changes to an event.
# Commit attribute setting, and check for a possible change
# of state from "embryonic" to "open".

proc eventCommit { id } {
    set NewAttrs NewEventAttrs_$id
    global $NewAttrs
    set Attrs EventAttrs_$id
    global $Attrs

    if { [info exists [set NewAttrs](state)] } {
	if { [set [set NewAttrs](state)] == "embryonic" } {
	    setEventAttr $id opened [clock seconds]
	    setEventAttr $id state "open"
	}
    }

    # Commit values
    foreach ix [array names $NewAttrs] {
	set [set Attrs]($ix) [set [set NewAttrs]($ix)]
    }

    # Force an update within 10s; save state
    ::persist::dump 10
#    ::persist::dumpAll

    notifyCheck $id
}

proc getEventAttr { id attr } {
    set Attrs EventAttrs_$id
    global $Attrs

    return [set [set Attrs]($attr)]
}

# Remove {} characters from log entry so that we can use
# it in a list construct (is this really necessary?).
# Also, prepend current timestamp and a space.

proc prepareLogEntry { e } {

    regsub -all "\[{}\]" $e "" e
    set e [format "%d %s" [clock seconds] $e]
    return $e
}

# Internal routine; common code between monitor- and
# human-initiated logging.

proc addLogEntry { id max type entry } {
    set Attrs EventAttrs_$id
    global $Attrs

    set entry [prepareLogEntry $entry]

    if { $type == "log" } {
	catch { recordDowntime $id $entry }
    }

    lappend ${Attrs}($type) $entry
    set log [set [set Attrs]($type)]
    if { $max != 0 } {
	if { [llength $log] >= $max } {
	    set log [lrange $log 1 end]
	}
    }
    setEventAttr $id $type $log
}

# This is for "monitor-initiated logging", not to be confused
# with the case history (attribute "history").

proc eventLog { id entry } {
    global eventLogLimit
    global eventLogAdd

    addLogEntry $id $eventLogLimit log $entry
    set eventLogAdd($id) 1
    setEventAttr $id "updated" [clock seconds]
}

# This is for human-initiated logging, i.e. the case history
# (or the pieces of it required/needed); attribute "history".

proc eventHistoryAdd { id user entry } {
    global eventHistAdd
    
    # Insert a single space at the start of each line,
    # avoiding to create lines with only a space character.
    regsub -all "^" $entry " " entry
    regsub -all "\n" $entry "\n " entry
    regsub -all "\n \n" $entry "\n\n" entry

    set e [format "%s\n%s" $user $entry]
    addLogEntry $id 0 history $e
    set eventHistAdd($id) 1
}

# Save history entry to disk in preparation of
# removal from in-memory data.

proc saveEvent { id } {
    set Attrs EventAttrs_$id
    global EventState
    global eventSaveDir

    set s [clock seconds]
    set d [format "%s/%s/%s" $eventSaveDir \
	    [clock format $s -format "%Y-%m"] \
	    [clock format $s -format "%d"] ]
    exec mkdir -p $d
    
    set f [format "%s/%s" $d $id]
    set fh [open $f "w"]
    ::persist::dumpGlobalVar $fh $Attrs
    close $fh
}

# This is called on the basis of UI events, and schedules
# an event to be scavenged later on

proc preCloseEvent { id } {
    global EventId
    global EventIdToIx
    global EventCloseTimes
    global PreClosedEventId

    set ix $EventIdToIx($id)

    set PreClosedEventId($ix) $id

    # a new event may now be created for this port
    catch { unset EventId($ix) }

    set EventCloseTimes($id) [clock seconds]
}

if { [info exists eventScavengerJob] } {
    catch { $eventScavengerJob destroy }
}
# Scavenger job runs each 30 minutes
set eventScavengerJob [job create \
	-interval [expr 30 * 60 * 1000] \
	-command scavengeClosedEvents]

# Remove events which have been in "closed" state longer
# than the expiry limit.

proc scavengeClosedEvents { } {
    global EventCloseTimes
    global eventScavenged
    global eventExpiry

    foreach id [array names EventCloseTimes] {
	set t0 $EventCloseTimes($id)
	set t1 [clock seconds]
	if { $t1 >= [expr $t0 + $eventExpiry] } {
	    puts [format "scavenging %s" $id]
	    # Be robust about scavenging
	    catch { saveEvent $id }
	    catch { notifyScavenge $id }
	    catch { closeEvent $id }; # Get rid of it for real
	    catch { unset EventCloseTimes($id) }
	}
    }
}

# We've seen instances where there exists events in "closed"
# state but EventCloseTimes does not contain the event.
# Paper over this problem by periodically checking for such events.

if { [info exists addMissingClosedJob] } {
    catch { $addMissingClosedJob destroy }
}
# Re-add missing events job runs each hour
set addMissingClosedJob [job create \
	-interval [expr 60 * 60 * 1000] \
	-command addMissingClosedEvents]

proc addMissingClosedEvents { } {
    global EventCloseTimes
    global EventId

    foreach ix [array names EventId] {
	set id $EventId($ix)
	if [catch {set state [getAttr $id "state"]} msg] {
	    puts [format "Could not get state of id %d" $id]
	    continue
	}
	if [info exists EventCloseTimes($id)] {
	    # This is the normal case
	    continue
	}
	puts [format "Setting EventCloseTimes for %d" $id]
	# Should be enough to trigger eventual closure/removal
	set EventCloseTimes($id) [clock seconds]
    }
}

# Finally ditch all remnants of an event, only done
# by the scavenger job above

proc closeEvent { id } {
    global EventState
    global EventIdToIx EventId
    global PreClosedEventId

    set EventState($id) "closed"

    set ix $EventIdToIx($id)
    set Attrs EventAttrs_$id
    global $Attrs

    ::persist::remove $Attrs
    catch { unset PreClosedEventId($ix) }
    catch { unset EventState($id) }
    catch { unset EventIdToIx($id) }
    catch { unset EventId($ix) }
    unset $Attrs
}

# Set "administrative state for event", to be called only
# from setEventAttr

proc setEventState { id state user } {
    global EventState
    global EventCloseTimes
    global eventStateChange

    set oldstate ""
    catch { set oldstate $EventState($id) }
    if { $oldstate == $state } { return; }
    if { $oldstate == "closed" } {
	error [format "Cannot reopen closed event %s" $id]
    }
    set EventState($id) $state

    # No reason to mess any more with embryonic events
    if { $state == "embryonic" } { return; }

    set eventStateChange($id) [format "%s %s" $oldstate $state]

    set e [format "state change %s -> %s (%s)" $oldstate $state $user]
    addLogEntry $id 0 history $e

    if { $state == "closed" } {
	saveEvent $id
	preCloseEvent $id
    }
}

# Dump the "simple" event attributes (no multi-line attributes)
# to the given channel, using putProc instead of "puts".

proc dumpEventAttrs { chan id putProc } {
    set Attrs EventAttrs_$id
    global $Attrs

    foreach ix [array names [set Attrs]] {
	if { $ix != "log" && $ix != "history" } {
	    $putProc $chan \
		    [format "%s: %s" $ix [set [set Attrs]($ix)]]
	}
    }
}

# Just return list of active events

proc eventIds { } {
    global EventId
    
    set ids {}
    foreach ix [array names EventId] {
	lappend ids $EventId($ix)
    }
    return $ids
}

# Does a given event id exist?

proc eventExists { id } {
    set Attrs EventAttrs_$id
    global $Attrs

    return [info exists $Attrs]
}

# Close all events related to router 'r' with reason 'msg'

proc closeEventsOnRouter { r msg } {
    global EventIdToIx

    # Close out any remaining reachability problems
    if [eventIxExists $r "reachability"] {
	set eid [eventId $r "reachability"]
	eventHistoryAdd $eid "monitor" $msg
	eventLog $eid $msg
	setEventAttr $eid "state" "closed"
	eventCommit $eid
    }

    # Close out any remaining portstate problems
    foreach eid [array names EventIdToIx] {
	set l [split $EventIdToIx($eid) ","]
	if { [lindex $l 0] == $r } {
	    eventHistoryAdd $eid "monitor" $msg
	    eventLog $eid $msg
	    setEventAttr $eid "state" "closed"
	    eventCommit $eid
	}
    }
}

proc isDown { id } {

    if [catch { set type [getEventAttr $id "type"] }] {
	return 0;		# New event, assume old state == "up"
    }
    if { $type == "portstate" } {
	set ps [getEventAttr $id "portstate"]
	if { $ps == "down" } { return 1 }
	if { $ps == "flapping" } { return 1 }
	return 0
    } elseif { $type == "reachability" } {
	set reach [getEventAttr $id "reachability"]
	if { $reach == "no-response" } { return 1 }
	return 0
    }
    return 0
}

proc recordDowntime { id le } {

    set ts [eventTimeStamp $le]
    set down [isDown $id]
    if { [isLogUpState $le] && $down } {
	set dt [expr $ts - [getEventAttr $id "lasttrans"]]
	# bogus, ignore
	if { $dt <= 0 } { return }
	set downtime 0
	catch { set downtime [getEventAttr $id "ac-down"] }
	set downtime [expr $downtime + $dt]
	setEventAttr $id "ac-down" $downtime
	setEventAttr $id "lasttrans" $ts
    } elseif { [isLogDownState $le] && ! $down } {
	setEventAttr $id "lasttrans" $ts
    }
}

# Return the "real event time" extracted from a logging line.
# This could be the encoded ifLastChange.
# However, ignore the ifLastChange value if it differs from the
# logging time stamp by more than 24h (some agents are severely
# broken in their ifLastChange implementation).

proc eventTimeStamp { le } {

    if [regexp {changed state from .* to .* on ([0-9]*)} $le dummy ts] {
	set lts [lindex $le 0]
	if { [expr $lts - $ts] > [expr 24 * 60 * 60] } {
	    return $lts
	} else {
	    return $ts
	}
    } else {
	return [lindex $le 0]
    }
}

proc isLogDownState { le } {

    if [regexp "linkDown" $le] { return 1 }
    if [regexp "no-response" $le] { return 1 }
    if [regexp {changed state from .* to down} $le] { return 1 }
    if [regexp {\) flapping, [0-9]+ flaps} $le] { return 1 }
    return 0
}

proc isLogUpState { le } {

    if [regexp "linkUp" $le] { return 1 }
    if [regexp "reachable" $le] { return 1 }
    if [regexp {changed state from .* to up} $le] { return 1 }
    if [regexp {changed state from .* to adminDown} $le] { return 1 }
    return 0
}

# Some simple debugging support

proc fixupDowntime { } {
    global EventIdToIx

    foreach id [array names EventIdToIx] {
	if [catch {set log [getEventAttr $id "log"]}] {
	    continue
	}

	set state "up"
	set downtime 0
	set lasttrans 0
	foreach le $log {
	    if { [isLogDownState $le] && $state == "up" } {
		set state "down"
		set start [eventTimeStamp $le]
		set lasttrans $start
	    }
	    if { [isLogUpState $le] && $state == "down" } {
		set state "up"
		set end [eventTimeStamp $le]
		set dt [expr $end - $start]
		if { $dt < 0 } { continue; }
		set downtime [expr $downtime + $dt]
		set lasttrans $end
	    }
	}

	setEventAttr $id "ac-down" $downtime
	setEventAttr $id "lasttrans" $lasttrans
	eventCommit $id
    }
}

proc dumpEventIds { } {
    global EventId

    set l [array names EventId]
    if { $l != {} } {
	foreach ix $l {
	    puts -nonewline [format "%s " $EventId($ix)]
	}
	puts ""
    }
}

proc dumpEvent { id } {
    set Attrs EventAttrs_$id
    global $Attrs
    global EventState
    global EventIdToIx

    foreach ix [array names [set Attrs]] {
	puts [format "%s: %s" $ix [set [set Attrs]($ix)]]
    }
}

proc fixupLastUpd { id }  {
    set Attrs EventAttrs_$id
    global $Attrs

    if { [info exists [set Attrs](last-upd)] } {
	unset [set Attrs](last-upd)
    }
    if { ! [info exists [set Attrs](log)] } { return; }
    set log [set [set Attrs](log)]
    set lastupd [lindex [lindex $log [expr [llength $log] - 1]] 0]
    setEventAttr $id "updated" $lastupd
    eventCommit $id
}

proc fixupLastUpds { } {
    global EventCloseTimes EventState

    foreach a {EventCloseTimes EventState} {
	foreach id [array names $a] {
	    fixupLastUpd $id
	}
    }
}

# To be used if the EventId array has somehow gotten out of sync with
# reality.  Has been known to happen.

proc fixupEventId { } {
    global EventId
    global EventCloseTimes

    foreach v [info globals] {
	if [regexp "EventAttrs_.*" $v] {
	    global $v

#	    puts "Checking $v"

	    if {    [info exists [set v](router)] && \
		    [info exists [set v](type)] && \
		    [info exists [set v](id)] } {

#		puts "Passed 1"

		set router [set [set v](router)]
		set type [set [set v](type)]
		set id [set [set v](id)]

		if { $type == "portstate" } {
		    if [catch {set ifindex [set [set v](ifindex)]}] {
#			puts "No IfIndex"
			continue
		    }
		    set ix [format "%s,%s,portstate" $router $ifindex]
		} else {
		    set ix [format "%s,reachability" $router]
		}

		set state [set [set v](state)]
		if { $state == "closed" && [info exists EventId($ix)] } {
		    puts [format "Removing closed event %s" $id]
		    catch { unset EventId($ix) }
		}
		if { ! [info exists EventId($ix)] && $state != "closed" } {
		    puts [format "Added id %s" $id]
		    set EventId($ix) $id
		}
		if { [info exists EventId($ix)] } {
		    if { $EventId($ix) != $id } {
			puts [format "Orphaned event %s" $id]
			set saveId $EventId($ix)

			# Call this one directly...
			setEventState $id "closed" "monitor"
			eventCommit $id
			closeEvent $id
			catch { unset EventCloseTimes($id) }
		    
			set EventId($ix) $saveId
			puts [format "Orphaned event %s closed" $id]
		    }
		}
	    }
	}
    }
}


proc cleanupDBvars { r } {
    global AddrToRouter
    global portToIfDescr
    global portToLocIfDescr
    global portState
    global isCisco

    puts [format "Router %s removed, cleaning up" $r]

    set msg [format "Router %s no longer monitored" $r]

    catch { closeEventsOnRouter $r $msg }
    catch { forgetFlaps $r $msg }

    # Clean up in internal "databases"
    foreach a [array names AddrToRouter] {
	if { $AddrToRouter($a) == $r } {
	    unset AddrToRouter($a)
	}
    }
    foreach a "portToIfDescr portToLocIfDescr portState" {
	foreach ix [array names $a] {
	    set l [split $ix ","]
	    if { [lindex $l 0] == $r } {
		unset [set a]($ix)
	    }
	}
    }
    catch { unset isCisco($r) }
}

