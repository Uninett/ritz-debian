#
# $Id$
#

set flapThreshold 35
set flapCeiling 256
set flapMin 1.5
set flapMult 2
set flapInitVal 2
set flapDecr 0.5
set flapDecrIntv 300


proc initFlaps { } {
    ::persist::add ::flapHistVal
    ::persist::add ::firstFlap
    ::persist::add ::lastFlap
    ::persist::add ::flaps
    ::persist::add ::lastAge
    ::persist::add ::flappedAboveThreshold

    ::persist::add ::flapping
}

proc flapVal { ix } {
    global flapHistVal

    if [info exists flapHistVal($ix)] {
	return $flapHistVal($ix)
    }
    return 0
}

proc flapCount { ix } {
    global flaps

    if [info exists flaps($ix)] {
	return $flaps($ix)
    }
    return 0
}

proc intfFlap { ix } {
    global flapHistVal flapCeiling flapMult flaps

    if { ! [info exists flapHistVal($ix)] } {
	firstFlap $ix
	return
    }

    ageIntfFlap $ix

    set x $flapHistVal($ix)
    set x [expr $x * $flapMult]
    set x [min $x $flapCeiling]
    set flapHistVal($ix) $x
    
    incr flaps($ix)
    set lastFlap($ix) [clock seconds]

    return
}

proc ageIntfFlap { ix } {
    global flapHistVal lastFlap lastAge
    global flapCeiling
    global flapDecrIntv flapDecr

    set now [clock seconds]
    
    if { [info exists lastAge($ix)] } {
	set last $lastAge($ix)
    } else {
	set last $lastFlap($ix)
    }
    set delta_steps [expr (0.0 + ($now - $last)) / $flapDecrIntv]
    set lastAge($ix) $now

    set x $flapHistVal($ix)
    if { [catch {set x [expr pow($x,pow($flapDecr,$delta_steps))]} msg] } {
	if { [regexp "too small" $msg] } {
	    set x 0
	} else {
	    error $msg $msg
	}
    }
    set x [min $x $flapCeiling]

#    puts [format "%s: ix %s old flapval %s new flapval %s steps %s" \
#	    [getStamp] \
#	    $ix $flapHistVal($ix) $x $delta_steps]

    set flapHistVal($ix) $x
}

proc flapping { ix } {
    global flapThreshold flapMin
    global flappedAboveThreshold

    ageIntfFlap $ix
    set x [flapVal $ix]

    if { $x < $flapMin } {
	return 0
    }
    if { $x > $flapThreshold } {
	set flappedAboveThreshold($ix) 1
	return 1
    }
    if [info exists flappedAboveThreshold($ix)] {
	return 1
    }
    return 0
}

proc wasFlapping { ix } {
    global flappedAboveThreshold

    return [info exists flappedAboveThreshold($ix)]
}

proc firstFlap { ix } {
    global flapInitVal flapHistVal firstFlap lastFlap flaps

#    puts [format "%s: firstFlap %s" [getStamp] $ix]
    set now [clock seconds]
    set firstFlap($ix) $now
    set flapHistVal($ix) $flapInitVal
    set flaps($ix) 1
    set lastFlap($ix) $now
}

proc unFlap { ix } {

#    puts [format "%s: unFlap %s" [getStamp] $ix]
    foreach v {flapHistVal firstFlap lastFlap flaps lastAge \
	    flappedAboveThreshold } {
	global $v
	catch { unset [set v]($ix) }
    }
}

proc flapAger { } {
    global flapHistVal lastFlap flaps lastAge
    global flapThreshold flapMin flapCeiling
    global flapDecrIntv flapDecr flapMult
    global flappedAboveThreshold
    global portToIfDescr portToLocIfDescr
    global portState
    
#    puts [format "%s: %s" [getStamp] "flapAger running"]

    foreach ix [array names flapHistVal] {

	ageIntfFlap $ix

	set x [flapVal $ix]
#	puts [format "%s: flapAger: flapval: %3s port %s" \
#		[getStamp] $x $ix]

	if { $x < $flapMin } {
#	    puts [format "%s: flapAger: %s aged below threshold (%s)" \
#		    [getStamp] $ix $x]

	    set l [split $ix ","]
	    set router [lindex $l 0]
	    set i [lindex $l 1]
	    if [wasFlapping $ix] {
		if { [info exists portToIfDescr($ix)] } {
		    set s [format \
			    "%s: intf \"%s\" ix %d stopped flapping (aging)" \
			    $router $portToIfDescr($ix) $i]
		} else {
		    set s [format "%s: ix %d stopped flapping (aging)" \
			    $router $i]
		}
		log $s

		if [closedEventIxExists $ix portstate] {
		    set el [closedEventId $ix portstate]
		    if [eventIxExists $ix portstate] {
			set el [format "$el %s" [eventId $ix portstate]]
		    }
		} else {
		    set el [eventId $ix portstate]
		}

		if [catch {	# Ignore possible errors
				# may be during startup phase
		    foreach eid $el {

			# If we lack information, revisit later
			if { ! [::config::confExists $router address] } {
			    continue;
			}
			if { ! [::config::confExists $router priority] } {
			    continue;
			}
			if { ! [info exists portToLocIfDescr($ix)] } {
			    continue;
			}
			if { ! [info exists portToIfDescr($ix)] } {
			    continue;
			}
			# Hm, if this is a new event, we need to set
			# "state" and "opened".

			setEventAttr $eid "id" $eid
			setEventAttr $eid "type" "portstate"
			setEventAttr $eid "flapstate" "stable"
			setEventAttr $eid "port" $portToIfDescr($ix)
			setEventAttr $eid "portstate" $portState($router,$i)
			setEventAttr $eid "router" $router
			setEventAttr $eid "polladdr" \
				[::config::conf $router address]
			setEventAttr $eid "priority" \
				[::config::conf $router priority]
			setEventAttr $eid "ifindex" $i
			setEventAttr $eid "descr" $portToLocIfDescr($ix)

			eventLog $eid $s

			eventCommit $eid
		    }
		} msg] {
		    log [format "flapAger error: %s" $msg]
		}
	    
		set oldstate $portState($router,$i)
		set portState($router,$i) "flapping"
		if [catch { pollSingleIf [handle $router] $i }] {
		    set portState($router,$i) $oldstate
		}
		
	    }
	    unFlap $ix
	}
    }
}

if [info exists flapAgerJob] {
    catch { $flapAgerJob destroy }
}
set flapAgerJob [job create \
	-interval [expr $flapDecrIntv * 1000] \
	-command flapAger]


# Should we ignore this trap message?
# If there's an open case for this router port, no.
# If received right after reload, yes.
# If state reported is the same as the one we have recorded,
# and a new trap does not reoccur within 5 minutes, yes.
# Otherwise, don't ignore the trap message.

proc ignoreTrap { r ifIndex updown } {
    global RestartTime
    global portState
    global LastSameTrap

    set now [clock seconds]

    set ix [format "%s,%s" $r $ifIndex]

    # If there's an open case for this router/port, don't ignore.
    if { [eventIxExists $ix "portstate"] } {
	return 0;		# do not ignore
    }

    # If we do not know it restarted, do not ignore (should never
    # happen now that we record the reported sysUpTime.0 from each and
    # every trap message.
    if { ! [info exists RestartTime($r)] } {
	log [format "Oops!  Do not know restart time for %s" $r]
	return 0
    }

    # If restart happened more than 5 minutes ago...
    if { [expr $now - $RestartTime($r)] > [expr 60 * 5] } {
	# Do not ignore traps indicating different state than known
	if { $portState($ix) != $updown } {
	    return 0
	}
	# Do not ignore successive traps within a 5 minute interval
	# indicating same state as previosly known.
	if { [info exists LastSameTrap($ix)] } {
	    if { [expr $now - $LastSameTrap($ix)] < [expr 60 * 5] } {
		set LastSameTrap($ix) $now
		return 0
	    }
	}
	set LastSameTrap($ix) $now
    }

    # Ignoring traps the first 5 minutes after restart

    log [format \
	    "Ignored %s trap for %s ix %s (state %s), restarted %s" \
	    $updown $r $ifIndex $portState($r,$ifIndex) \
	    [clock format $RestartTime($r)]]
    return 1;			# ignore the rest
}


proc linkTrans { router ifIndex descr updown reason } {
    global flapping
    global portToLocIfDescr rtrPortToDescr
    global portState
    
    set ix [format "%s,%s" $router $ifIndex]

    # Only watch matching port if config exists
    if { [::config::confExists $router watchpat] } {
	set wp [::config::conf $router watchpat]
	if { ! [regexp $wp $descr] } {
#	    log [format "%s intf \"%s\" link%s not watched" $router $descr $updown]
	    return 0
	}
    }

    # Ignore matching port if ignore-pattern exists and matches
    if { [::config::confExists $router ignorepat] } {
	if { [regexp [::config::conf $router ignorepat] $descr] } {
#	    log [format "%s intf \"%s\" link%s ignored" $router $descr $updown]
	    return 0
	}
    }

    # Log details
    set fmt "%s: intf %s ix %d link%s"
    if { $reason != "" } {
	set fmt [format "%s, reason \"%s\"" $fmt $reason]
    }
    detailLog $router $ifIndex [format $fmt $router $descr $ifIndex $updown]
    set rtrPortToDescr($ix) $descr

    set ldescr ""
    if { [info exists portToLocIfDescr($ix)] } {
	set ldescr $portToLocIfDescr($ix)
    }

    if { [ignoreTrap $router $ifIndex [string tolower $updown]] } {
	return;			# just ignore
    }

    intfFlap $ix;		# Increase penalty value etc.

    if { [flapping $ix] } {
	if { ! [info exists flapping($ix)] } {
	    # Not previously known to be flapping -- open a case for it
	    set eid [eventId $ix "portstate"]

	    setEventAttr $eid "router" $router
	    setEventAttr $eid "port" $descr
	    setEventAttr $eid "portstate" [string tolower $updown]
	    set portState($ix) [string tolower $updown]
	    setEventAttr $eid "ifindex" $ifIndex
	    setEventAttr $eid "flapstate" "flapping"
	    setEventAttr $eid "polladdr" [::config::conf $router address]
	    setEventAttr $eid "priority" [::config::conf $router priority]
	    if { $ldescr != "" } {
		setEventAttr $eid "descr" $ldescr
	    }
	    if { $reason != "" } {
		setEventAttr $eid "reason" $reason
	    }

	    set s [format "%s: intf \"%s\" ix %d (%s) flapping, %d flaps,\
		    penalty %5.2f"\
		    $router $descr $ifIndex \
		    $ldescr \
		    [flapCount $ix] \
		    [flapVal $ix]]
	    log $s
	    eventLog $eid $s
	    eventCommit $eid

	    set flapping($ix) 1
	}
	if { [expr [flapCount $ix] % 100] == 0 } {
	    set s [format \
		    "%s: intf \"%s\" ix %d (%s), %d flaps, penalty %5.2f" \
		    $router $descr $ifIndex \
		    $ldescr \
		    [flapCount $ix] \
		    [flapVal $ix]]
	    log $s
	}
    } else {
	# Not flapping, but we still want to record trap message
	set eid [eventId $ix "portstate"]
	    
	setEventAttr $eid "router" $router
	setEventAttr $eid "port" $descr
	setEventAttr $eid "portstate" [string tolower $updown]
	set portState($ix) [string tolower $updown]
	setEventAttr $eid "ifindex" $ifIndex
	setEventAttr $eid "polladdr" [::config::conf $router address]
	setEventAttr $eid "priority" [::config::conf $router priority]
	if { $ldescr != "" } {
	    setEventAttr $eid "descr" $ldescr
	}

	if { [info exists flapping($ix)] } {
	    setEventAttr $eid "flapstate" "stable"
	    
	    set s [format "%s: intf \"%s\" ix %d (%s) stopped flapping" \
		    $router $descr $ifIndex $ldescr]
	    log $s
	    eventLog $eid $s
	    
	    unset flapping($ix)
	    set portState($ix) "flapping"
	    unFlap $ix
	}
	
	set fmt "%s: intf \"%s\" ix %d link%s"
	if { $reason != "" } {
	    setEventAttr $eid "reason" $reason
	    set fmt [format "%s, reason \"%s\"" $fmt $reason]
	}
	set s [format $fmt $router $descr $ifIndex $updown]
	log $s
	eventLog $eid $s
	
	eventCommit $eid
	# Poll immediately just to be certain of interface state change
	pollSingleIf [handle $router] $ifIndex
	# Check again in two minutes
	after [expr 120 * 1000] pollSingleIf [handle $router] $ifIndex
    }
}

proc clearFlapInternal { router ifIndex user reason } {
    global flapping
    global rtrPortToDescr portToLocIfDescr
    
    set ix [format "%s,%s" $router $ifIndex]

    if { ! [eventIxExists $ix "portstate"] } {
	return;			# Nothing to clear
    }
    set eid [eventId $ix "portstate"]
    if [catch {set fs [getEventAttr $eid "flapstate"]}] {
	return;			# No flapstate
    }
    if { $fs != "flapping" } {
	return;			# Not flapping 
    }
    set descr ""
    if [info exists rtrPortToDescr($ix)] {
	set descr $rtrPortToDescr($ix)
    }
    set ldescr ""
    if { [info exists portToLocIfDescr($ix)] } {
	set ldescr $portToLocIfDescr($ix)
    }
    eventHistoryAdd $eid $user $reason
    setEventAttr $eid "flapstate" "stable"
    set s [format "%s: intf \"%s\" ix %d (%s) %s" \
	    $router $descr $ifIndex $ldescr $reason]
    log $s
    eventLog $eid $s
    eventCommit $eid

    unset flapping($ix)
    unFlap $ix
}

proc clearFlap { router ifIndex user } {

    clearFlapInternal $router $ifIndex $user "Flapstate manually cleared"

    set ix [format "%s,%s" $router $ifIndex]
    set portState($ix) "flapping";# to get logged state change
    pollSingleIf [handle $router] $ifIndex
}

# Forget any flapstate and close any cases
# related to router 'r' with msg 'msg' appearing in the
# event log and history.

proc forgetFlaps { r msg } {
    global firstFlap
    
    foreach ix [array names firstFlap] {
	set l [split $ix ","]
	if { [lindex $l 0] == $r } {
	    set ifIndex [lindex $l 1]

	    clearFlapInternal $r $ifIndex "no more polling by monitor" $msg
	}
    }
}

proc dumpHistVals { } {
    global flapHistVal flaps

    foreach ix [array names flapHistVal] {
	puts [format "%s flaps %d penalty %5.2f" \
		$ix $flaps($ix) $flapHistVal($ix)]
    }
}

