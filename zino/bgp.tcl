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

    set old [eventIxExists $ix bgp]
    
    set eid [eventId $ix bgp]

    if { $old } {
	if { [getEventAttr $eid "bgpAS"] == $bgpPeerAdminStatus } {
	    return ;			# already noted
	}
    }

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

proc bgpAdminUp { sh ix vbl } {

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }
    set r [name $sh]

    set old [eventIxExists $ix bgp]
    
    if { ! $old } {
	return ;			# not noted, so no need to bother
    }

    set eid [eventId $ix bgp]

    if { [getEventAttr $eid "bgpAS"] == $bgpPeerAdminStatus } {
	return ;			# already noted
    }

    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" $bgpPeerState
    setEventAttr $eid "bgpAS" $bgpPeerAdminStatus
    setEventAttr $eid "remote-addr" $bgpPeerRemoteAddr
    setEventAttr $eid "remote-AS" $bgpPeerRemoteAs
    setEventAttr $eid "peer-uptime" 0
    setEventAttr $eid "lastevent" "peer is now admin turned on"

    set s [format "%s peer %s AS %s is now turned on (%s)" \
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

    set old [eventIxExists $ix bgp]

    set eid [eventId $ix bgp]

    if { $old } {
	if { [getEventAttr $eid "bgpOS"] == "down" } {
	    return ;			# already noted
	}
    }

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
	if { ! [info exists $v] } {
	    log [format "router %s misses %s" $r $v]
	    log [format "router %s vbl %s" $r $vbl]
	    return
	}
    }
    set ix [format "%s,%s" $r $bgpPeerRemoteAddr]

#    if { $localAS($sh) != $bgpPeerRemoteAs } {
#	log [format "debug: BGP r %s loc %s rem %s AS %s as %s os %s box-up %s peer-up %s" \
#		 $r $bgpPeerLocalAddr $bgpPeerRemoteAddr \
#		 $bgpPeerRemoteAs $bgpPeerAdminStatus $bgpPeerState \
#		 $uptime $bgpPeerFsmEstablishedTime]
#    }

    # Bug in JunOS -- info from IPv6 BGP sessions spill over
    if { $bgpPeerRemoteAddr == "0.0.0.0" } { return }
    # Bug in earlier Cisco IOS, info from elsewhere (IPv6?) spills over
    if { $bgpPeerRemoteAddr == "32.1.7.0" } { return }

    if { $bgpPeerState == "established" } {
	set handled 0
	if { [info exists bgpPeerUpTime($ix)] } {
	    # Ignore session resets as a result of a restart
	    if { $uptime >= $bgpPeerUpTime($ix) } {
		if { $bgpPeerUpTime($ix) > $bgpPeerFsmEstablishedTime } {
		    # peer was reset, but is now up
		    if { $localAS($sh) != $bgpPeerRemoteAs } {
			# external peer session was reset => alert
			bgpExternalReset $sh $ix $vbl
			log [format "debug: Noted external reset for %s: %s" $r $ix]
			set handled 1
		    }
		}
	    }
	}
	if { ! $handled && $localAS($sh) != $bgpPeerRemoteAs } {
	    if [eventIxExists $ix bgp] {
		set eid [eventId $ix bgp]
		if { [getEventAttr $eid "bgpOS"] != "established" } {
		    bgpExternalReset $sh $ix $vbl
		    log [format "debug: BGP session up for %s: %s" $r $ix]
		}
	    }
	}
    } else {
	if { $bgpPeerAdminStatus == "stop" } {
	    if { ! [info exists bgpPeerAdminState($ix)] } {
		set bgpPeerAdminState($ix) "unknown"
	    }
	    if { $bgpPeerAdminState($ix) != $bgpPeerAdminStatus } {
		# admin turned off
		bgpAdminDown $sh $ix $vbl
		log [format "debug: Router %s peer %s AS %s admin-down" \
			 $r $bgpPeerRemoteAddr $bgpPeerRemoteAs]
	    }
	} else {
	    if { ! [info exists bgpPeerAdminState($ix)] } {
		set bgpPeerAdminState($ix) "unknown"
	    }
	    if { $bgpPeerAdminState($ix) != $bgpPeerAdminStatus && \
		     $localAS($sh) != $bgpPeerRemoteAs } {
		bgpAdminUp $sh $ix $vbl
	    }
	    if { ! [info exists bgpPeerOperState($ix)] } {
		set bgpPeerOperState($ix) "established"
	    }
	    # peer is not up, but configured to be up
	    # Check if it's an external AS
	    if { $localAS($sh) != $bgpPeerRemoteAs && \
		 $bgpPeerOperState($ix) == "established" } {
		# First verify that we've been up more than 10 minutes
		# before we flag it as an alert
		if { $uptime > 600 } {
		    bgpOperDown $sh $ix $vbl
		    log [format "debug: Router %s peer %s AS %s os %s (down)" \
			     $r $bgpPeerRemoteAddr \
			     $bgpPeerRemoteAs $bgpPeerState]
		} else {
		    log [format "debug: Router %s peer %s AS %s is %s (down), but uptime = %d" \
			     $r $bgpPeerRemoteAddr $bgpPeerRemoteAs \
			     $bgpPeerState $uptime]
		}
	    }
	}
    }
    set bgpPeerOperState($ix) $bgpPeerState
    set bgpPeerAdminState($ix) $bgpPeerAdminStatus
    set bgpPeerUpTime($ix) $bgpPeerFsmEstablishedTime


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
	# Judiciously avoid using "local" variables;
	# the callback is executed in the global context!

#	puts [format "%s %s %s" %S %E "%V"]
	if { "%E" != "noError" } {
	    return
	}

	if { [lindex [lindex "%V" 0] 1] == "noSuchObject" } {
	    return
	}
	if { [lindex [lindex "%V" 0] 2] == 0 } {
	    return
	}
	set localAS(%S) [lindex [lindex "%V" 0] 2]
#	puts [format "localAS(%s) %s" %S $localAS(%S)]

	checkBGPpeers %S [expr [mib scan \
				    [lindex [lindex "%V" 1] 0] \
				    [lindex [lindex "%V" 1] 2] \
				   ] / 100]
    }
}
