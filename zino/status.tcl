#
# $Id$
#
# A simple trap-directed up/down status poller.
#

proc initStatus { } {

    ::persist::add ::AddrToRouter
    ::persist::add ::portToIfDescr
    ::persist::add ::portToLocIfDescr
    ::persist::add ::portState
    ::persist::add ::isCisco

    setSWalkEhandler swalkErrorHandler

    initBGP
}


# Create mapping table address -> handle
# and handle -> address-list

proc recordAddr { sh vbl } {
    global AddrToRouter RouterToAlist
    global lastPoll

    set lastPoll($sh) [clock seconds]

    ::persist::add ::AddrToRouter

    set ixVbl [lindex $vbl 0]
    set adVbl [lindex $vbl 1]
    set ix [lindex $ixVbl 2]
    set ad [lindex $adVbl 2]

    set r [name $sh]

    set AddrToRouter($ad) $r
    lappend RouterToAlist($r) $ad
}

# Get current list of IP addresses, store mapping(s)

proc getAddrList { sh } {
    global RouterToAlist

    catch { unset RouterToAlist([name $sh]) }
    if { [catch {
	$sh walk x "ipAdEntIfIndex ipAdEntAddr" { recordAddr $sh $x }
    } msg] } {
	set m [format "%s: %s" "getAddrList" $msg]
	error $m $m
    }
    return
}

proc basePollList { sh } {
    global isCisco

    set bl "ifIndex ifDescr ifAdminStatus ifOperStatus ifLastChange ifAlias"
    if { [info exists isCisco([name $sh])] } {
	if { $isCisco([name $sh]) } {
	    lappend bl "locIfDescr" "locIfReason"
	}
    }
    return $bl
}

proc pollSingleIf { sh ix } {

#    puts [format "%s: polling single intf %s" [name $sh] $ix]

    set bpl [basePollList $sh]
    foreach v [split $bpl] {
	lappend pl [format "%s.%d" $v [expr $ix - 1]]
	lappend sl [mib oid $v]
    }
    if [catch {set res [$sh getnext $pl]} msg] {
	log [format "%s: error polling single intf %s: %s" \
		[name $sh] $ix $msg]
    }
    set fres [filterLowestMatching $sl $ix $res]
    if { "$fres" == "" } {
	log [format "%s: error polling single intf %s: no match" \
		[name $sh] $ix]
	return
    }
    recordIntf $sh $fres
    Response $sh

#    puts [format "%s: poll of single intf %s OK" [name $sh] $ix]
}

proc eventTime { uptime changetime } {
    set now [clock seconds]
    return [expr $now - ($uptime - $changetime) / 100]
}

proc recordIntf { sh vbl } {
    global portState portToIfDescr portToLocIfDescr
    global lastPoll

    set lastPoll($sh) [clock seconds]

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }

    set r [name $sh]

    # Here test for ifAdminStatus=on, ifOperStatus=down,
    # if event already known etc.

    # First a few sanity checks
    if { ! [info exists ifDescr] } {
	return
    }
    if { ! [info exists ifIndex] } {
	return
    }
    if { $ifIndex == "" } {
	# just ignore, bug in 11.2(2)
	return
    }

    # Check if interface state changes should be ignored,
    # could e.g. be ISDN or dialup interfaces

    # If watch pattern exists, only watch matching interfaces
    if { [::config::confExists $r watchpat] } {
	set wp [::config::conf $r watchpat]
	if { ! [regexp $wp $ifDescr] } {
#	    log [format "%s intf \"%s\" not watched" $r $ifDescr]
	    return
	}
    }

    # If ignore pattern exists, ignore matching interfaces
    if { [::config::confExists $r ignorepat] } {
	if { [regexp [::config::conf $r ignorepat] $ifDescr] } {
#	    log [format "%s intf \"%s\" ignored" $r $ifDescr]
	    return
	}
    }

#    puts [format "%s: %s" $r $ifIndex]
    set ix [format "%s,%s" $r $ifIndex]

    set portToIfDescr($ix) $ifDescr
    if { [info exists locIfDescr] } {
	if { $locIfDescr != "" } {
	    set portToLocIfDescr($ix) $locIfDescr
	}
    } elseif [info exists ifAlias] {
	if { $ifAlias != "" } {
	    set portToLocIfDescr($ix) $ifAlias
	}
    }

    foreach v "ifAdminStatus ifOperStatus" {
	if { ! [info exists $v] } {
	    set m [format "no %s from %s for port %s" \
		    [name $sh] $ifIndex]
	    error $m $m
	}
    }

    set state [format "admin%s" [ucFirst $ifAdminStatus]]
    # A special tweak so that we report ports in oper-down (but
    # admin-up) state first time we see them
    if { ! [info exists portState($ix)] && \
	    $ifOperStatus != "up" && \
	    $state != "adminDown" } {
	set portState($ix) "unknown"
    }
    if { $state == "adminUp" } {
	set state $ifOperStatus
    }

    if { [info exists portState($ix)] } {
	if { $portState($ix) != $state } {
	    set eid [eventId $ix portstate]
	    setEventAttr $eid "router" $r
	    setEventAttr $eid "port" $ifDescr
	    setEventAttr $eid "portstate" $state
	    setEventAttr $eid "ifindex" $ifIndex
	    setEventAttr $eid "polladdr" [::config::conf $r address]
	    setEventAttr $eid "priority" [::config::conf $r priority]

	    set sysUpTime [getUptime $sh]
	    if { $sysUpTime == 0 } {
		set sysUpTime [mib scan ifLastChange $ifLastChange]
	    }

	    set fmt "%s: port \"%s\" ix %s"
	    if { [info exists locIfDescr] } {
		setEventAttr $eid "descr" $locIfDescr
		set fmt [format "%s (%s)" $fmt $locIfDescr]
	    } elseif [info exists ifAlias] {
		setEventAttr $eid "descr" $ifAlias
		set fmt [format "%s (%s)" $fmt $ifAlias]
	    }
	    set fmt [format "%s %s" $fmt \
		    "changed state from %s to %s on %s" ]
	    if { [info exists locIfReason] } {
		setEventAttr $eid "reason" $locIfReason
		set fmt [format "%s reason \"%s\"" $fmt $locIfReason]
	    }
	    set s [format $fmt $r $ifDescr $ifIndex \
		    $portState($ix) $state \
		    [eventTime $sysUpTime\
		      [mib scan ifLastChange $ifLastChange]]]
	    log $s
	    eventLog $eid $s

	    eventCommit $eid

	    # Re-verify state change after 2 minutes
	    after [expr 120 * 1000] pollSingleIf $sh $ifIndex
	}
    }
    set portState($ix) $state
}

proc pollIfs { sh } {
    set vl [basePollList $sh]
    sparseWalk $sh $vl x [list eval recordIntf $sh {$x}]
}

# Return uptime in 100'ths of a second, or 0 if unknown

proc getUptime { sh } {
    global save_uptime

    $sh get "sysUpTime.0" {
	global save_uptime
	if { "%E" != "noError" } {
	    log "getUptime: %E"
	    if { "%E" ==  "noResponse" } {
		noResponse "%S"
	    }
	    return
	}
	Response "%S"

	set save_uptime(%S) [mib scan [lindex [lindex "%V" 0] 0] \
				 [lindex [lindex "%V" 0] 2]]
    }

    $sh wait

#    log [format "debug: %s getUptime past wait point" [name $sh]]

    if [info exists save_uptime($sh)] {
	return $save_uptime($sh)
    } else {
	log [format "%s: returning 0 uptime" [name $sh]]
	return 0
    }
}

proc swalkErrorHandler { sh err } {

    if { $err == "noResponse" } {
	noResponse $sh
    } else {
	error $err
    }
}

proc cleanupDelayedResponse { sh } {
    global responseCheckInProgress

    if [catch { set r [name $sh] }] {
	set r "(deleted)"
    }

    # cleanup any remaining check jobs
    if [info exists responseCheckInProgress($sh)] {
	# just ignore errors here...
	catch { after cancel delayedCheckResponse $sh }
	catch { after cancel lastDelayedCheckResponse $sh }
	catch { unset responseCheckInProgress($sh) }
	# log [format "cleaned up delayed check for %s" $r]
    }
}

proc checkResponse { sh } {

    $sh get "sysUpTime.0" {
	if { "%E" != "noError" } {
	    if { "%E" == "noResponse" } {
		noResponse "%S"
	    }
	} else {
	    Response "%S"
	}
    }
}

proc delayedCheckResponse { sh } {

    if [catch { set r [name $sh] }] {
	cleanupDelayedResponse $sh
	return 0
    }

    log [format "checking reachability of %s" $r]
    $sh get "sysUpTime.0" {
	if { "%E" != "noError" } {
	    if { "%E" == "noResponse" } {
		noResponse %S
	    }
	} else {
	    Response %S
	    cleanupDelayedResponse %S
	}
    }
}

proc lastDelayedCheckResponse { sh } {
    global responseCheckInProgress

    delayedCheckResponse $sh
    catch { unset responseCheckInProgress($sh) }
}

proc delayedNoResponse { sh } {
    global responseCheckInProgress
    
    $sh get "sysUpTime.0" {

	set r [name %S]
#	log [format "checking reachability of %s" $r]
    
	if { "%E" != "noError" } {
	    if { "%E" == "noResponse"} {
#		log [format "checking: no response from %s" $r]

		set doit 0
		# Do we already have an event for this failure?
		if [eventIxExists $r "reachability"] {
		    set eid [eventId $r "reachability"]
		    if { [getEventAttr $eid "reachability"] != "no-response" } {
			set doit 1
		    }
		} else {
		    set doit 1
		}
		#	log [format "checking %s, doit is %s" $r $doit]

		if { $doit != 0 } {
		    set eid [eventId $r "reachability"]
		    setEventAttr $eid "router" $r
		    setEventAttr $eid "reachability" "no-response"
		    setEventAttr $eid "polladdr" [::config::conf $r address]
		    setEventAttr $eid "priority" [::config::conf $r priority]
		    set s [format "%s no-response" $r]
		    eventLog $eid $s
		    eventCommit $eid
		    log $s
		    after [expr 60  * 1000] delayedCheckResponse %S
		    after [expr 120 * 1000] delayedCheckResponse %S
		    after [expr 240 * 1000] delayedCheckResponse %S
		    after [expr 480 * 1000] delayedCheckResponse %S
		    after [expr 960 * 1000] lastDelayedCheckResponse %S
		} else {
		    cleanupDelayedResponse %S
		}
	    }
	} else {
	    log [format "checking: cancelling check of %s" $r]
	    cleanupDelayedResponse %S
	}
    }
}

proc noResponse { sh } {
    global responseCheckInProgress
    
    if [info exists responseCheckInProgress($sh)] {
	log [format "no-response from %s but checking already" [name $sh]]
	return
    }
    log [format "no-response from %s, starting delayed check" [name $sh]]
    after [expr 60 * 1000] delayedNoResponse $sh
    set responseCheckInProgress($sh) 1
}

proc doResponse { router eid } {

    set rch "reachability"

    set reach [getEventAttr $eid $rch]
    if { $reach != "reachable" } {
	setEventAttr $eid $rch "reachable"
	set s [format "%s reachable" $router]
	eventLog $eid $s
	eventCommit $eid
	log $s
    }
}

proc Response { sh } {

    set r [name $sh]

#    puts [format "Response from %s" $r]

    set rch "reachability"

    if {[eventIxExists $r $rch]} {
	set eid [eventId $r $rch]
	doResponse $r $eid
	cleanupDelayedResponse $sh
    }
    if {[closedEventIxExists $r $rch]} {
	set eid [closedEventId $r $rch]
	doResponse $r $eid
	cleanupDelayedResponse $sh
    }
}

proc schedPollRouter { sh } {
    global lastPoll
    global lastSched
    global lastSchedTime

    if [info exists lastPoll($sh)] {
	set now [clock seconds]
	set delta [expr $now - $lastPoll($sh)]
	if { $delta < 60 } {
#	    log [format "debug: %s skipping poll within 60s" [name $sh]]
	    return
	}
    }

    set now [clock seconds]
    if [info exists lastSched($sh)] {
	if { $lastSched($sh) > $now } {
#	    log [format "debug: skipping %s, already scheduled" [name $sh]]
	    return
	}
    }
    if { ! [info exists lastSchedTime] } {
	set lastSchedTime [expr $now + 5]
    }
    set lastSchedTime [expr $lastSchedTime + 3]
    if { $lastSchedTime < $now } {
	set lastSchedTime [expr $now + 1.5]
    }
    set lastSched($sh) $lastSchedTime

    set msintv [expr int(( $lastSchedTime - $now ) * 1000)]
    after $msintv [list pollRouter [name $sh]]

#    log [format "debug: %s scheduled poll in %d ms" [name $sh] $msintv]
}

# Poll BGP once every 5 rounds

set delay_factor(checkBGP) 5

proc pollRest { sh vbl } {
    global isCisco
    global delay_factor

    set r [name $sh]
#    log [format "debug: %s: proceeding with poll" $r]

    Response $sh

    set isCisco($r) [oidPfxMatch [mib oid cisco] \
			 [lindex [lindex "$vbl" 1] 2]]

#    log [format "debug: %s: getting address list" $r]
    getAddrList $sh

#    log [format "debug: %s: polling interfaces" $r]
    if { [catch {pollIfs $sh} msg] } {
	log [format "%s: error polling router: %s" $r $msg]
	return
    }

    # Maybe add more later to this list
    foreach p "checkBGP" {
	if { [info proc $p] == $p } {
	    if [info exists delay_factor($sh,$p)] {
		if { $delay_factor($sh,$p) <= 0 } {
		    set delay_factor($sh,$p) $delay_factor($p)
		    # ...and fallthrough to actually do it
		} else {
		    set delay_factor($sh,$p) [expr $delay_factor($sh,$p) - 1]
		    continue
		}
	    } else {
		set delay_factor($sh,$p) $delay_factor($p)
		continue
	    }
#	    log [format "debug: %s: doing %s" $r $p]
	    if { [catch {$p $sh} msg] } {
		log [format "%s: error doing %s: %s" $r $p $msg]
	    }
	}
    }
}

proc pollRouter { r } {

#    log [format "debug: %s: starting poll" $r]
    [handle $r] get "sysUpTime.0 sysObjectID.0" {
	if { "%E" != "noError" } {
	    if { "%E" == "noResponse" } {
		noResponse %S
	    }
	    return
	}
	pollRest %S "%V"
    }
}

proc knownRouter { r } {

    if [::config::confExists $r address] {
	return 1
    } else {
	return 0
    }
}

proc fixupStates { } {
    global portState

    foreach ix [array names portState] {
	if { [eventIxExists $ix "portstate"] } {
	    set id [eventId $ix "portstate"]
	    if { [getEventAttr $id "portstate"] != $portState($ix) } {
		puts [format "fixing %s id %s attr = %s, state = %s" \
			$ix $id \
			[getEventAttr $id "portstate"] \
			$portState($ix)]
		setEventAttr $id "portstate" $portState($ix)
		eventCommit $id
	    }
	}
    }
}
