#!/store/bin/scotty
#
# $Id$
#
# A simple trap-directed up/down status poller.
#

proc initStatus { } {

    persistVar AddrToRouter
    persistVar portToIfDescr
    persistVar portToLocIfDescr
    persistVar portState
    persistVar isCisco

    setSWalkEhandler swalkErrorHandler
}


# Returns sysObjectID, or "" on failure

proc getSysID { sh } {

    if { [catch {set svbl [$sh get "sysObjectID.0"]} msg] } {
	set m [format "%s: %s" "getSysID" $msg]
	error $m $m
    }
    set name  [lindex [lindex $svbl 0] 0]
    set value [lindex [lindex $svbl 0] 2]
    Response $sh
    return [mib scan $name $value]
}

# Create mapping table address -> handle
# and handle -> address-list

proc recordAddr { sh vbl } {
    global AddrToRouter RouterToAlist
    global cx

    persistVar AddrToRouter

    set ixVbl [lindex $vbl 0]
    set adVbl [lindex $vbl 1]
    set ix [lindex $ixVbl 2]
    set ad [lindex $adVbl 2]

    set r $cx($sh,name)

    set AddrToRouter($ad) $r
    lappend RouterToAlist($r) $ad
}

# Get current list of IP addresses, store mapping(s)

proc getAddrList { sh } {
    global RouterToAlist cx

    catch { unset RouterToAlist($cx($sh,name)) }
    if { [catch {
	$sh walk x "ipAdEntIfIndex ipAdEntAddr" { recordAddr $sh $x }
    } msg] } {
	set m [format "%s: %s" "getAddrList" $msg]
	error $m $m
    }
    return
}

proc basePollList { sh } {
    global cx isCisco

    set bl "ifIndex ifDescr ifAdminStatus ifOperStatus ifLastChange"
    if { [info exists isCisco($cx($sh,name))] } {
	if { $isCisco($cx($sh,name)) } {
	    lappend bl "locIfDescr" "locIfReason"
	}
    }
    return $bl
}

proc pollSingleIf { sh ix } {
    global cx

    foreach v [split [basePollList $sh]] {
	lappend vl [format "%s.%d" $v $ix]
    }
    if { [catch { $sh get $vl { recordIntf "%S" "%V" } msg }] } {
	log [format "%s: error polling intf %d: %s" \
		$cx($sh,name) $ix $msg]
    }
    Response $sh
}

proc eventTime { uptime changetime } {
    set now [clock seconds]
    return [expr $now - ($uptime - $changetime) / 100]
}

proc recordIntf { sh vbl } {
    global cx IgnorePat portState
    global portToIfDescr portToLocIfDescr
    global Address
    global Priority

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }

    set r $cx($sh,name)

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
    # could e.g. be ISDN or dialup interface
    if { [info exists IgnorePat($r)] } {
	if { [regexp $IgnorePat($r) $ifDescr] } {
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
    }

    foreach v "ifAdminStatus ifOperStatus" {
	if { ! [info exists $v] } {
	    set m [format "no %s from %s for port %s" \
		    $cx($sh,name) $ifIndex]
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
	    setEventAttr $eid "polladdr" $Address($r)
	    setEventAttr $eid "priority" $Priority($r)

	    if { [catch {set sysUpTime [getUptime $sh]} msg] } {
		log [format "%s: %s" $r $msg]
		noResponse $sh
		# Fake it
		set sysUpTime [mib scan ifLastChange $ifLastChange]
	    }

	    set fmt "%s: port \"%s\" ix %s"
	    if { [info exists locIfDescr] } {
		setEventAttr $eid "descr" $locIfDescr
		set fmt [format "%s (%s)" $fmt $locIfDescr]
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

# Return uptime in 100'ths of a second, or err

proc getUptime { sh } {
    global cx

    if { [catch { set uvbl [$sh get "sysUpTime.0"]} msg] } {
	set m [format "%s: %s" "getUptime" $msg]
	error $m $m
    }
    set name  [lindex [lindex $uvbl 0] 0]
    set value [lindex [lindex $uvbl 0] 2]
#    puts [format "%s uptime %s" $cx($sh,name) $value]
    Response $sh

    return [mib scan $name $value]
}

proc checkConfig { sh } {
    global cx isCisco

    set uptime [getUptime $sh]
    set sysid [getSysID $sh]
    set isCisco($cx($sh,name)) [oidPfxMatch [mib oid cisco] $sysid]
    getAddrList $sh
}

proc swalkErrorHandler { sh err } {

    if { $err == "noResponse" } {
	noResponse $sh
    } else {
	error $err
    }
}

proc delayedCheckResponse { sh } {
    global responseCheckInProgress
    global cx

    set r $cx($sh,name)

    log [format "checking reachability of %s" $r]
    if [checkResponse $sh] {
	Response $sh

	# cleanup any remaining check jobs
	after cancel delayedCheckResponse $sh
	after cancel lastDelayedCheckResponse $sh
	unset responseCheckInProgress($sh)
	log [format "cleaned up after response from %s" $r]
    }
}

proc lastDelayedCheckResponse { sh } {
    global responseCheckInProgress

    delayedCheckResponse $sh
    unset responseCheckInProgress($sh)
}

proc delayedNoResponse { sh } {
    global cx
    global Address Priority
    
    if { ! [checkResponse $sh] } {
	set r $cx($sh,name)

	set doit 0
	if [eventIxExists $r "reachability"] {
	    set eid [eventId $r "reachability"]
	    if { [getEventAttr $eid "reachability"] != "no-response" } {
		set doit 1
	    }
	} else {
	    set doit 1
	}
	if { $doit != 0 } {
	    set eid [eventId $r "reachability"]
	    setEventAttr $eid "router" $r
	    setEventAttr $eid "reachability" "no-response"
	    setEventAttr $eid "polladdr" $Address($r)
	    setEventAttr $eid "priority" $Priority($r)
	    set s [format "%s no-response" $r]
	    eventLog $eid $s
	    eventCommit $eid
	    log $s
	    after [expr 60  * 1000] delayedCheckResponse $sh
	    after [expr 120 * 1000] delayedCheckResponse $sh
	    after [expr 240 * 1000] delayedCheckResponse $sh
	    after [expr 480 * 1000] delayedCheckResponse $sh
	    after [expr 960 * 1000] lastDelayedCheckResponse $sh
	}
    }
}

proc noResponse { sh } {
    global responseCheckInProgress
    global cx
    
    if [info exists responseCheckInProgress($sh)] {
	log [format "no-response from %s but checking already" $cx($sh,name)]
	return
    }
    log [format "no-response from %s, starting delayed check" $cx($sh,name)]
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
    global cx

    set r $cx($sh,name)

#    puts [format "Response from %s" $r]

    set rch "reachability"

    if {[eventIxExists $r $rch]} {
	set eid [eventId $r $rch]
	doResponse $r $eid
    }
    if {[closedEventIxExists $r $rch]} {
	set eid [closedEventId $r $rch]
	doResponse $r $eid
    }
}

proc checkResponse { sh } {
    global cx

    if [catch { getUptime $sh } msg] {
	log [format "%s: %s" $cx($sh,name) $msg]
	if [regexp "noResponse" $msg] {
	    return 0
	}
    }
    return 1
}

proc checkConfigs { } {
    global cx Address
    foreach r [array names Address] {
	if { [catch {checkConfig $cx($r,handle)} msg] } {
	    log [format "%s: %s" $r $msg]
	    if { [regexp "noResponse" $msg] } {
		noResponse $cx($r,handle)
	    }
	}
    }
}

proc pollRouter { r } {
    global cx

    set sh $cx($r,handle)
    if { [catch {checkConfig $sh} msg] } {
	if { [regexp "noResponse" $msg] } {
	    noResponse $sh
	}
	return
    }
    if { [catch {pollIfs $sh} msg] } {
	log [format "%s: error polling router: %s" $r $msg]
	return
    }
}

proc startRouterPollJob { r } {
    global pollJobs pollJob Interval

    set j [job create \
	    -interval [expr $Interval($r) * 60 * 1000] \
	    -command [list pollRouter $r]]
    lappend pollJobs $j
    set pollJob($r) $j
}

proc startRouterPollJobs { } {
    global Address DefaultInterval

    set n [array size Address]
    set intv [expr $DefaultInterval * 60 * 1000 / $n]
    set delay 0
    foreach r [array names Address] {
	after $delay startRouterPollJob $r
	set delay [expr $delay + $intv]
    }
}

proc stopRouterPollJobs { } {
    global Address pollJobs

    foreach r [array names Address] {
	after cancel startRouterPollJob $r
    }
    if { [info exists pollJobs] } {
	foreach j $pollJobs {
	    catch { $j destroy }
	}
    }
}

proc setupHandle { r } {
    global cx Address Timeout Retry

    if { [info exists cx($r,handle)] } {
	return;			# already done
    }
    set s [snmp session \
	    -address $Address($r) \
	    -community $cx($r,community) \
	    -timeout $Timeout($r) \
	    -retries $Retry($r) ]
    set cx($r,handle) $s
    set cx($s,name) $r
}

proc setupHandles { } {
    global Address

    foreach r [array names Address] {
	setupHandle $r
    }
}

proc stopRouterPolling { r } {
    global pollJob cx

    catch { $pollJob($r) destroy }
    catch { unset pollJob($r) }
    after cancel startRouterPollJob $r

    catch {
	set h $cx($r,handle)
	$h destroy
	unset cx($r,handle)
    }
}

proc stopPollDeletedRouters { } {
    global DeletedRouter Address cx

    foreach r [array names DeletedRouter] {
	stopRouterPolling $r

	unset DeletedRouter($r)
	catch { unset Address($r) }
	catch { unset cx($h,name) }
    }
}

proc startPollNewRouters { } {
    global NewRouter
    global DefaultInterval

    set n [array size NewRouter]
    if { $n == 0 } { return; }
    set intv [expr $DefaultInterval * 60 * 1000 / $n]
    set delay 0

    foreach r [array names NewRouter] {
	setupHandle $r
	after $delay startRouterPollJob $r
	set delay [expr $delay + $intv]

#puts [format "starting polling router %s" $r]

	unset NewRouter($r)
    }
}

proc restartPollChangedRouters { } {
    global ChangedRouter
    global DefaultInterval

    set n [array size ChangedRouter]
    if { $n == 0 } { return; }
    set intv [expr $DefaultInterval * 60 * 1000 / $n]
    set delay 0

    foreach r [array names ChangedRouter] {
	stopRouterPolling $r
	setupHandle $r
	after $delay startRouterPollJob $r
	set delay [expr $delay + $intv]

	puts [format "Restarting polling router %s" $r]

	unset ChangedRouter($r)
    }
}

proc knownRouter { r } {
    global Address cx

    return [expr [info exists Address($r)] && [info exists cx($r,handle)]]
}

proc fixupPollJob { } {
    global pollJob

    foreach j [job info] {
	set s [$j configure]
	if { [regexp pollRouter $s] } {
	    set r [lindex [lindex $s 1] 1]
#	    puts [format "%s: %s" $j $r]
	    set pollJob($r) $j
	}
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
