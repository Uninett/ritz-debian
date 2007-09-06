#
# $Id$
#
# Check status of BGP peer sessions
#

proc initBGP {} {

    ::persist::add ::bgpPeerOperState
    ::persist::add ::bgpPeerAdminState
    ::persist::add ::bgpPeerUpTime
    ::persist::add ::localAS
    ::persist::add ::bgpPeers
    ::persist::add ::sawPeer
}

proc bgpAdminDown { sh ix vbl } {

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }
    set r [name $sh]

    set eid [eventId $ix bgp]
    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" "down"
    setEventAttr $eid "bgpAS" $bgpPeerAdminStatus
    setEventAttr $eid "remote-addr" $bgpPeerRemoteAddr
    setEventAttr $eid "remote-AS" $bgpPeerRemoteAs
    setEventAttr $eid "peer-uptime" 0
    setEventAttr $eid "lastevent" "peer is admin turned off"

    set s [format "%s peer %s AS %s is turned off (%s)" \
	       $r $bgpPeerRemoteAddr $bgpPeerRemoteAs $bgpPeerAdminStatus]
    log $s
    eventLog $eid $s

    eventCommit $eid
}

proc bgpOperDown { sh ix vbl } {

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }
    set r [name $sh]

    set eid [eventId $ix bgp]
    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" "down"
    setEventAttr $eid "bgpAS" $bgpPeerAdminStatus
    setEventAttr $eid "remote-addr" $bgpPeerRemoteAddr
    setEventAttr $eid "remote-AS" $bgpPeerRemoteAs
    setEventAttr $eid "peer-uptime" $bgpPeerFsmEstablishedTime
    setEventAttr $eid "lastevent" "peer is down"

    set s [format "%s peer %s AS %s is down (%s)" \
	       $r $bgpPeerRemoteAddr $bgpPeerRemoteAs $bgpPeerState]
    log $s
    eventLog $eid $s

    eventCommit $eid
}

proc bgpExternalReset { sh ix vbl } {

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }
    set r [name $sh]

    set eid [eventId $ix bgp]
    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" $bgpPeerState
    setEventAttr $eid "bgpAS" $bgpPeerAdminStatus
    setEventAttr $eid "remote-addr" $bgpPeerRemoteAddr
    setEventAttr $eid "remote-AS" $bgpPeerRemoteAs
    setEventAttr $eid "peer-uptime" $bgpPeerFsmEstablishedTime
    setEventAttr $eid "lastevent" "peer was reset (now up)"

    set s [format "%s peer %s AS %s was reset (now up)" \
	       $r $bgpPeerRemoteAddr $bgpPeerRemoteAs]
    log $s
    eventLog $eid $s

    eventCommit $eid
}

proc recordBGPpeer { sh uptime vbl } {
    global bgpPeerOperState
    global bgpPeerAdminState
    global localAS bgpPeerUpTime
    global bgpPeers sawPeer
    global lastPoll

    set lastPoll($sh) [clock seconds]

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }
    set r [name $sh]
    foreach v "bgpPeerState bgpPeerAdminStatus \
	bgpPeerLocalAddr bgpPeerRemoteAddr bgpPeerRemoteAs \
	bgpPeerFsmEstablishedTime" {
	if { ! [info exists $v] } { return }
    }
    set ix [format "%s,bgp,%s" $r $bgpPeerRemoteAddr]

    # Bug in JunOS -- info from IPv6 BGP sessions spill over
    if { $bgpPeerLocalAddr == "0.0.0.0" } { return }

    if { $bgpPeerState == "established" } {
	if { [info exists bgpPeerUpTime($ix)] } {
	    # Ignore session resets as a result of a restart
	    if { $uptime >= $bgpPeerUpTime($ix) } {
		if { $bgpPeerUpTime($ix) > $bgpPeerFsmEstablishedTime } {
		    # peer was reset, but is now up
		    if { $localAS($sh) != $bgpPeerRemoteAs } {
			# external peer session was reset => alert
			bgpExternalReset $sh $ix $vbl
		    }
		}
	    }
	}
	set bgpPeerUpTime($ix) $bgpPeerFsmEstablishedTime
    } else {
	if { $bgpPeerAdminStatus == "stop" } {
	    # admin turned off
	    if { [info exists bgpPeerAdminState($ix)] } {
		if { $bgpPeerAdminState($ix) != "stop" } {
		    # admin state changed => alert
		    bgpAdminDown $sh $ix $vbl
		}
	    }
	    set bgpPeerAdminState($ix) "stop"
	} else {
	    # peer is not up, but configured to be up
	    if { $localAS($sh) != $bgpPeerRemoteAs } {
		# First verify that we've been up more than 10 minutes
		# before we flag it as an alert
		if { $uptime > 600 } {
		    # external peer is down
		    if { [info exists bgpPeerOperState($ix)] } {
			if { $bgpPeerOperState($ix) != "down" } {
			    # oper state change => alert
			    bgpOperDown $sh $ix $vbl
			}
		    }
		    set bgpPeerOperState($ix) "down"
		}
	    } else {
		# iBGP peer is down
		# Do periodic validation separately at a later stage
		set bgpPeerOperState($ix) "down"
	    }
	}
    }

    # Possibly add to list of peers, record it as recently seen
    # to allow later garbage collection
    set found 0
    set now [clock seconds]
    if { [info exists bgpPeers($r)] } {
	foreach p $bgpPeers($r) {
	    if { $p == $bgpPeerRemoteAddr } {
		set found 1
		set k [format "%s,%s" $r $p]
		set sawPeer($k) $now
	    }
	}
    }
    if { ! $found } {
	lappend bgpPeers($r) $bgpPeerRemoteAddr
	set k [format "%s,%s" $r $bgpPeerRemoteAddr]
	set sawPeer($k) $now
    }

#    puts [format "%-20s %5d  %-8s %-8s %s" \
	      $bgpPeerRemoteAddr $bgpPeerRemoteAs \
	      $bgpPeerState $bgpPeerAdminStatus \
	      $bgpPeerFsmEstablishedTime]
}

proc checkBGPpeers { sh up } {
    
    set vl "bgpPeerState bgpPeerAdminStatus \
	bgpPeerLocalAddr bgpPeerRemoteAddr bgpPeerRemoteAs \
	bgpPeerFsmEstablishedTime"
    sparseWalk $sh $vl x [list eval recordBGPpeer $sh $up {$x}]
}

proc checkBGP { sh } {
    global localAS

    $sh get "bgpLocalAs.0 sysUpTime.0" {
#	puts [format "%s %s %s" %S %E "%V"]
	if { "%E" != "noError" } {
	    return
	}
	set lasv [lindex "%V" 0]
	set supv [lindex "%V" 1]

	if { [lindex $lasv 1] == "noSuchObject" } {
	    return
	}
	set as [lindex $lasv 2]
	if { $as == 0 } {
	    return
	}
#	puts [format "localAS(%s) %s" %S $as]
	set localAS(%S) $as

	set up100 [mib scan [lindex $supv 0] [lindex $supv 2]]
	set up [expr $up100 / 100]

#	puts [format "%s uptime %d secs (%s)" %S $up [lindex $supv 2]]

	checkBGPpeers %S $up
    }
}
