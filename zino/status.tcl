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
    ::persist::add ::isJuniper
    ::persist::add ::RunsOn

    setSWalkEhandler swalkErrorHandler

    initBGP
    initJNXalarm
}

proc isCisco { sh } {
    global isCisco

    if { [info exists isCisco([name $sh])] } {
	return $isCisco([name $sh])
    }
    return 0
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

    bulkWalk $sh "ipAdEntIfIndex ipAdEntAddr" 10 recordAddr {} errBulk
}

proc basePollList { sh } {

    set bl "ifIndex ifDescr ifAdminStatus ifOperStatus ifLastChange"
    if [isCisco $sh] {
	lappend bl "locIfReason"
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
	return
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
    global portState portToIfDescr
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
	    if [significantInterface $ix] {
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
		set fmt [format "%s (%s)" $fmt [description $ix]]
		setEventAttr $eid "descr" [description $ix]

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
	    } else {
		set fmt "ignoring %s port \"%s\" ix %s"
		set fmt [format "%s %s" $fmt "in-significant port changed"]
		set fmt [format "%s %s" $fmt "state from %s to %s"]
		set s [format $fmt $r $ifDescr $ifIndex \
			   $portState($ix) $state]
		log $s
	    }
	}
    }
    set portState($ix) $state
}

proc recordDescr { sh vbl } {

    set n [name $sh]
    set vn [format "descs_%s" $n]
    global $vn

    foreach vb $vbl {
	set n [mib name [lindex $vb 0]]
	set v [lindex $vb 2]
	set ix [lindex [split $n .] 1]
	if {$v != ""} {
	    set [set vn]($ix) $v
	}
    }
}

proc endDescrAll { sh } {

    if {! [isCisco $sh]} {
	endDescr $sh; # cisco devices use endDescr directly
    }
}

proc endDescr { sh } {
    global portToLocIfDescr

    set n [name $sh]
    set varname [format "descs_%s" $n]
    global $varname
    
    foreach ifix [array names $varname] {
	set ix [format "%s,%s" $n $ifix]
	set newval [set [set varname]($ifix)]
	set change 0
	set new 0
	if { ! [info exists portToLocIfDescr($ix)] } {
	    set change 1
	    set new 1
	} else {
	    if { $portToLocIfDescr($ix) != $newval } {
		set change 1
	    }
	}
	if { $change } {
	    if { ! $new } {
		log [format "changing desc for %s from %s to %s" \
			 $ix $portToLocIfDescr($ix) $newval]
	    } else {
		log [format "setting desc for %s to %s" $ix $newval]
	    }
	    set portToLocIfDescr($ix) $newval
	}
    }
    foreach ix [array names portToLocIfDescr] {
	set l [split $ix ","]
	set rp [lindex $l 0]
	set ifix [lindex $l 1]
	if {$rp == $n} {
	    if {! [info exists [set varname]($ifix)]} {
		log [format "unset desc for %s, was %s" \
			 $ix $portToLocIfDescr($ix)]
		unset portToLocIfDescr($ix)
	    }
	}
    }
    catch { unset [set varname] }
}

proc errBulk { sh err } {

    if { $err == "noResponse" } {
	noResponse $sh
    } else {
	set m [format "getDescrFields: %s" $err]
	error $m $m
    }
}

proc description { ix } {
    global portToLocIfDescr

    if [info exists portToLocIfDescr($ix)] {
	return $portToLocIfDescr($ix)
    }
    return ""
}

proc getDescrFields { sh } {
    global portToLocIfDescr

    set n [name $sh]
    set varname [format "descs_%s" $n]
    catch { unset $varname }

    bulkWalk $sh "ifAlias" 10 recordDescr endDescrAll errBulk

    # Do the same for locIfDescr for Cisco devices
    # May return longer than 64 chars (ifAlias is limited to 64)
    if [isCisco $sh] {
	bulkWalk $sh "locIfDescr" 10 recordDescr endDescr errBulk
    }
}

proc recordStacking { sh vbl } {

    set n [name $sh]
    set varname [format "runs_on_%s" $n]
    global $varname

    foreach vb $vbl {
	set n [mib name [lindex $vb 0]]
	set v [lindex $vb 2]
	set l [split $n .]
	set ul [lindex $l 1]; # upper layer
	set ll [lindex $l 2]; # lower layer
    
	if { $v != "active" } {
	    continue
	}
	if { $ul == 0 || $ll == 0 } {
	    continue
	}
	set [set varname]($ul) $ll
    }
}

proc endStacking { sh } {
    global RunsOn

    set n [name $sh]
    set varname [format "runs_on_%s" $n]
    global $varname
    
    foreach ifix [array names $varname] {
	set ix [format "%s,%s" $n $ifix]
	set newval [set [set varname]($ifix)]
	set change 0
	set new 0
	if { ! [info exists RunsOn($ix)] } {
	    set new 1
	} else {
	    if { $RunsOn($ix) != $newval } {
		set change 1
	    }
	}
	if { $change || $new } {
	    if { $new } {
		log [format "interface %s runs on %s" $ix $newval]
	    } elseif { $change } {
		log [format "changing layering: %s runs on %s (was %s)" \
			 $ix $newval $RunsOn($ix)]
	    }
	    set RunsOn($ix) $newval
	}
    }
    foreach {ix val} [array get RunsOn [format "%s,*" $n]] {
	set l [split $ix ","]
	set rp [lindex $l 0]
	set ifix [lindex $l 1]
	if {! [info exists [set varname]($ifix)] } {
	    log [format "unset layering for %s, was %s" \
		     $ix $RunsOn($ix)]
	    unset RunsOn($ix)
	}
    }
    catch { unset [set varname] }
}

proc getLayering { sh } {

    set n [name $sh]
    set varname [format "runs_on_%s" $n]
    global $varname
    catch { unset [set varname] }

    bulkWalk $sh "ifStackTable" 20 recordStacking endStacking errBulk
}

proc cleanupLayering { r } {
    global RunsOn

    array unset RunsOn "$r,*"
}

proc runsOn { ix } {
    global RunsOn

    if [info exists RunsOn($ix)] {
	return $RunsOn($ix)
    } else {
	return ""
    }
}

proc significantInterface { ix } {
    global portToLocIfDescr
    
    # If a given interface runs on top of another,
    # and has no description field set (or it's empty),
    # it's deemed to not be "significant".  This is intended
    # to get rid of alarms for e.g. "unit 0" sub-interfaces
    # in Juniper routers.

    if { [runsOn $ix] != "" } {
	if { [description $ix] == "" } {
	    return 0
	}
    }
    return 1
}


proc pollIfs { sh } {

    getDescrFields $sh
    getLayering $sh

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

proc reachable { sh } {
    set rch "reachability"
    set r [name $sh]

    if { [eventIxExists $r $rch] } {
	set eid [eventId $r $rch]
	set status [getEventAttr $eid $rch]
	if { $status == "no-response" } {
	    return 0
	}
    }
    # else assume all is well
    return 1
}

proc noResponse { sh } {
    global responseCheckInProgress
    
    if [info exists responseCheckInProgress($sh)] {
	log [format "no-response from %s but checking already" [name $sh]]
	return
    }
    # Quench messages if we know it's not reachable
    if [reachable $sh] {
	log [format "no-response from %s, starting delayed check" [name $sh]]
    }
    after [expr 60 * 1000] delayedNoResponse $sh
    set responseCheckInProgress($sh) 1
}

proc doResponse { sh } {

    set r [name $sh]
    set rch "reachability"

    set eids ""
    if [eventIxExists $r $rch] {
	set eid [eventId $r $rch]
	lappend eids $eid
    }
    if [closedEventIxExists $r $rch] {
	set eid [closedEventId $r $rch]
	lappend eids $eid
    }
    foreach eid $eids {
	if { [getEventAttr $eid $rch] != "reachable" } {
	    setEventAttr $eid $rch "reachable"
	    set s [format "%s reachable" $r]
	    eventLog $eid $s
	    eventCommit $eid
	    log $s
	}
    }
}

proc Response { sh } {

    set r [name $sh]

#    puts [format "Response from %s" $r]

    set rch "reachability"

    if {[eventIxExists $r $rch] || \
	    [closedEventIxExists $r $rch]} {
	doResponse $sh
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
set delay_factor(checkJNXalarm) 0

proc pollRest { sh vbl } {
    global isCisco
    global isJuniper
    global delay_factor

    set r [name $sh]
#    log [format "debug: %s: proceeding with poll" $r]

    Response $sh

    set isCisco($r) [oidPfxMatch [mib oid cisco] \
			 [lindex [lindex "$vbl" 1] 2]]
    set isJuniper($r) [oidPfxMatch [mib oid juniperMIB] \
			   [lindex [lindex "$vbl" 1] 2]]

#    log [format "debug: %s: getting address list" $r]
    getAddrList $sh

#    log [format "debug: %s: polling interfaces" $r]
    if { [catch {pollIfs $sh} msg] } {
	log [format "%s: error polling router: %s" $r $msg]
	return
    }

    # Maybe add more later to this list
    foreach p { "checkBGP" "checkJNXalarm" } {
	if { [info proc $p] == $p } {
	    if { ! [info exists delay_factor($sh,$p)] } {
		set delay_factor($sh,$p) $delay_factor($p)
	    }
	    if { $delay_factor($sh,$p) <= 0 } {
		set delay_factor($sh,$p) $delay_factor($p)
		# ...and fallthrough to actually do it
	    } else {
		set delay_factor($sh,$p) [expr $delay_factor($sh,$p) - 1]
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
