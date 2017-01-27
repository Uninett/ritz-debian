#
# $Id$
#
# Check status of BGP peer sessions
#

proc initBGP {} {
    global BgpStyle
    global BgpVarlist
    global BgpVar
    global localAsVars
    global localAsVar

    ::persist::add ::bgpPeerOperState
    ::persist::add ::bgpPeerAdminState
    ::persist::add ::bgpPeerUpTime
    ::persist::add ::localAS
    ::persist::add ::bgpPeers
    ::persist::add ::sawPeer

    set localAsVars { "jnxBgpM2PeerLocalAs" "cbgpLocalAs" "bgpLocalAs" }

    foreach v $localAsVars {
	# use first char of var name to indicate type
	set BgpStyle($v) [string index $v 0]
	set localAsVar([string index $v 0]) $v
    }

    set BgpVarlist(j) "jnxBgpM2PeerState jnxBgpM2PeerStatus \
	    jnxBgpM2PeerLocalAddr \
	    jnxBgpM2PeerRemoteAddr jnxBgpM2PeerRemoteAs \
	    jnxBgpM2PeerFsmEstablishedTime"
    set BgpVarlist(c) "cbgpPeer2State cbgpPeer2AdminStatus \
	    cbgpPeer2LocalAddr cbgpPeer2RemoteAs \
	    cbgpPeer2FsmEstablishedTime"
    set BgpVarlist(b) "bgpPeerState bgpPeerAdminStatus \
	    bgpPeerLocalAddr bgpPeerRemoteAddr bgpPeerRemoteAs \
	    bgpPeerFsmEstablishedTime"

    set BgpVar(PeerState,j) "jnxBgpM2PeerState"
    # Would have liked to use jnxBgpM2CfgPeerAdminStatus,
    # but it is unimplemented as of 15.1F6 and optional in the MIB
    set BgpVar(PeerAdminStatus,j) "jnxBgpM2PeerStatus"
    set BgpVar(PeerLocalAddr,j) "jnxBgpM2PeerLocalAddr"
    set BgpVar(PeerRemoteAddr,j) "jnxBgpM2PeerRemoteAddr"
    set BgpVar(PeerRemoteAs,j) "jnxBgpM2PeerRemoteAs"
    set BgpVar(PeerFsmEstablishedTime,j) "jnxBgpM2PeerFsmEstablishedTime"

    set BgpVar(PeerState,c) "cbgpPeer2State"
    set BgpVar(PeerAdminStatus,c) "cbgpPeer2AdminStatus"
    set BgpVar(PeerLocalAddr,c) "cbgpPeer2LocalAddr"
    set BgpVar(PeerRemoteAddr,c) "cbgpPeer2RemoteAddr";# needs synthesis
    set BgpVar(PeerRemoteAs,c) "cbgpPeer2RemoteAs"
    set BgpVar(PeerFsmEstablishedTime,c) "cbgpPeer2FsmEstablishedTime"

    set BgpVar(PeerState,b) "bgpPeerState"
    set BgpVar(PeerAdminStatus,b) "bgpPeerAdminStatus"
    set BgpVar(PeerLocalAddr,b) "bgpPeerLocalAddr"
    set BgpVar(PeerRemoteAddr,b) "bgpPeerRemoteAddr"
    set BgpVar(PeerRemoteAs,b) "bgpPeerRemoteAs"
    set BgpVar(PeerFsmEstablishedTime,b) "bgpPeerFsmEstablishedTime"
}

proc cleanupBGPvars { r } {
    global localAS bgpPeers

    foreach a { bgpPeerAdminState bgpOperState bgpPeerUpTime sawPeer } {
	global $a
	array unset $a "$r,*"
    }
    set h [handle $r]
    catch { unset localAS($h) }
    catch { unset bgpPeers($r) }
}

# Extract an IP address from a variable index, for new-style Cisco MIB
proc cExtractAddr { vn } {

    set l [split $vn "."]
    if { [lindex $l 1] == "1" } {# ipv4
	return [format "%s.%s.%s.%s" \
		[lindex $l 3] [lindex $l 4] \
		[lindex $l 5] [lindex $l 6]]
    }
    if { [lindex $l 1] == "2" } {# ipv6
	return [format "%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x:%02x" \
		[lindex $l 3] [lindex $l 4] [lindex $l 5] [lindex $l 6] \
		[lindex $l 7] [lindex $l 8] [lindex $l 9] [lindex $l 10] \
		[lindex $l 11] [lindex $l 12] [lindex $l 13] [lindex $l 14] \
		[lindex $l 15] [lindex $l 16] [lindex $l 17] [lindex $l 18] \
		]
    }
    # what?!?
    return "unknown"
}

# Provide a properly pretty-printed ipv4 or ipv6 address
proc fixupAddr { v } {
    if [regexp "^..:..:..:..\$" $v] {
	# hex-formatted IPv4
	set l [split $v ":"]
	return [format "%d.%d.%d.%d" \
		0x[lindex $l 0] 0x[lindex $l 1] \
		0x[lindex $l 2] 0x[lindex $l 3]]
    }
    if [regexp "^\[0-9\]{1,3}.\[0-9\]{1,3}.\[0-9\]{1,3}.\[0-9\]{1,3}\$" $v] {
	# ipv4, already ok
	return $v
    }
    if [regexp ":\[0-9a-fA-F\]+:" $v] {
	# must be ipv6, assume it has the right number of octets
	set l [split $v ":"]
	set s ""
	set init 1
	while {[llength $l] != 0} {
	    set a [lindex $l 0]
	    set b [lindex $l 1]
	    set l [lrange $l 2 end]
	    if {!$init} {
		set s [format "%s:" $s]
	    } else {
		set init 0
	    }
	    set s [format "%s%s%s" $s $a $b]
	}
	regsub -all "0000" $s "0" s
	regsub -all ":0+(\[^0:\]+)" $s ":\\1" s
	set s [string tolower $s]
	# Replace longest string of 0's with just ::
	foreach sub \
		":0:0:0:0:0:0:0 :0:0:0:0:0:0 :0:0:0:0:0 :0:0:0:0 :0:0:0 :0:0" \
		{
	    if {[regsub $sub $s ":" s] != 0} {
		return $s
	    }
	}
	return $s
    }
    return $v
}


proc bgpAdminDown { sh sty ix vbl } {
    global BgpVar

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
	if { $sty == "c" } {
	    if { $var eq "cbgpPeer2LocalAddr" } {
		set cbgpPeer2RemoteAddr [cExtractAddr [mib name $oid]]
	    }
	}
    }
    set r [name $sh]
    set old [eventIxExists $ix bgp]
    set eid [eventId $ix bgp]
    if { $old } {
	if { [getEventAttr $eid "bgpAS"] == \
		[set $BgpVar(PeerAdminStatus,$sty)] } {
	    return ;			# already noted
	}
    }
    set remote [fixupAddr [set $BgpVar(PeerRemoteAddr,$sty)]]
    set a_state [set $BgpVar(PeerAdminStatus,$sty)]
    set o_state [set $BgpVar(PeerState,$sty)]
    set remote_as [set $BgpVar(PeerRemoteAs,$sty)]

    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" "down"
    setEventAttr $eid "bgpAS" $a_state
    setEventAttr $eid "remote-addr" $remote
    setEventAttr $eid "remote-AS" $remote_as
    setEventAttr $eid "peer-uptime" 0
    setEventAttr $eid "lastevent" "peer is admin turned off"

    set s [format "%s peer %s AS %s is turned off (%s)" \
	       $r $remote $remote_as $a_state]
    log $s
    eventLog $eid $s
    eventCommit $eid
}

proc bgpAdminUp { sh sty ix vbl } {
    global BgpVar

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
	if { $sty == "c" } {
	    if { $var eq "cbgpPeer2LocalAddr" } {
		set cbgpPeer2RemoteAddr [cExtractAddr [mib name $oid]]
	    }
	}
    }
    set r [name $sh]
    set old [eventIxExists $ix bgp]
    if { ! $old } {
	return ;			# not noted, so no need to bother
    }
    set eid [eventId $ix bgp]

    set remote [fixupAddr [set $BgpVar(PeerRemoteAddr,$sty)]]
    set a_state [set $BgpVar(PeerAdminStatus,$sty)]
    set o_state [set $BgpVar(PeerState,$sty)]
    set remote_as [set $BgpVar(PeerRemoteAs,$sty)]

    if { [getEventAttr $eid "bgpAS"] == $a_state } {
	return ;			# already noted
    }

    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" $o_state
    setEventAttr $eid "bgpAS" $a_state
    setEventAttr $eid "remote-addr" $remote
    setEventAttr $eid "remote-AS" $remote_as
    setEventAttr $eid "peer-uptime" 0
    setEventAttr $eid "lastevent" "peer is now admin turned on"

    set s [format "%s peer %s AS %s is now turned on (%s)" \
	       $r $remote $remote_as $a_state]
    log $s
    eventLog $eid $s
    eventCommit $eid
}

proc bgpOperDown { sh sty ix vbl } {
    global BgpVar

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
	if { $sty == "c" } {
	    if { $var eq "cbgpPeer2LocalAddr" } {
		set cbgpPeer2RemoteAddr [cExtractAddr [mib name $oid]]
	    }
	}
    }
    set r [name $sh]
    set old [eventIxExists $ix bgp]
    set eid [eventId $ix bgp]
    if { $old } {
	if { [getEventAttr $eid "bgpOS"] == "down" } {
	    return ;			# already noted
	}
    }

    set remote [fixupAddr [set $BgpVar(PeerRemoteAddr,$sty)]]
    set a_state [set $BgpVar(PeerAdminStatus,$sty)]
    set o_state [set $BgpVar(PeerState,$sty)]
    set remote_as [set $BgpVar(PeerRemoteAs,$sty)]
    set est_time [set $BgpVar(PeerFsmEstablishedTime,$sty)]

    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" "down"
    setEventAttr $eid "bgpAS" $a_state
    setEventAttr $eid "remote-addr" $remote
    setEventAttr $eid "remote-AS" $remote_as
    setEventAttr $eid "peer-uptime" $est_time
    setEventAttr $eid "lastevent" "peer is down"

    set s [format "%s peer %s AS %s is down (%s)" \
	       $r $remote $remote_as $a_state]
    log $s
    eventLog $eid $s
    eventCommit $eid
}

proc bgpExternalReset { sh sty ix vbl } {
    global BgpVar

    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
	if { $sty == "c" } {
	    if { $var eq "cbgpPeer2LocalAddr" } {
		set cbgpPeer2RemoteAddr [cExtractAddr [mib name $oid]]
	    }
	}
    }
    set r [name $sh]
    set eid [eventId $ix bgp]

    set remote [fixupAddr [set $BgpVar(PeerRemoteAddr,$sty)]]
    set a_state [set $BgpVar(PeerAdminStatus,$sty)]
    set o_state [set $BgpVar(PeerState,$sty)]
    set remote_as [set $BgpVar(PeerRemoteAs,$sty)]
    set est_time [set $BgpVar(PeerFsmEstablishedTime,$sty)]

    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bgpOS" $o_state
    setEventAttr $eid "bgpAS" $a_state
    setEventAttr $eid "remote-addr" $remote
    setEventAttr $eid "remote-AS" $remote_as
    setEventAttr $eid "peer-uptime" $est_time
    setEventAttr $eid "lastevent" "peer was reset (now up)"

    set s [format "%s peer %s AS %s was reset (now up)" \
	       $r $remote $remote_as $a_state]
    log $s
    eventLog $eid $s
    eventCommit $eid
}

proc recordBGPpeer { sh sty uptime vbl } {
    global bgpPeerOperState
    global bgpPeerAdminState
    global localAS bgpPeerUpTime
    global bgpPeers sawPeer
    global lastPoll
    global BgpVar

    set lastPoll($sh) [clock seconds]
    set r [name $sh]
    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
	if { $sty == "c" } {
	    if { $var eq "cbgpPeer2LocalAddr" } {
#		log [format "Router %s getting RemoteAddr from %s" \
#			 $r [mib name $oid]]
		set cbgpPeer2RemoteAddr [cExtractAddr [mib name $oid]]
	    }
	}
    }
    foreach v "PeerState PeerAdminStatus \
	    PeerLocalAddr PeerRemoteAddr PeerRemoteAs \
	    PeerFsmEstablishedTime" {
	if { ! [info exists $BgpVar($v,$sty)] } {
	    log [format "router %s misses %s" $r $v]
	    log [format "router %s vbl %s" $r $vbl]
	    log [format "router %s locals %s" $r [info locals]]
	    return
	}
    }

    set a [set $BgpVar(PeerRemoteAddr,$sty)]
    set remote [fixupAddr $a]

    set ix [format "%s,%s" $r $a]

#    if { $localAS($sh) != [set $BgpVar("PeerRemoteAs",$sty)] } {
#	log [format "debug: BGP r %s loc %s rem %s AS %s as %s os %s box-up %s peer-up %s" \
#		 $r $bgpPeerLocalAddr $bgpPeerRemoteAddr \
#		 $bgpPeerRemoteAs $bgpPeerAdminStatus $bgpPeerState \
#		 $uptime $bgpPeerFsmEstablishedTime]
#    }

    # Bug in JunOS -- info from IPv6 BGP sessions spill over
    if { $remote == "0.0.0.0" } { return }
    # Bug in earlier Cisco IOS, info from elsewhere (IPv6?) spills over
    if { $remote == "32.1.7.0" } { return }

    set a_state   [set $BgpVar(PeerAdminStatus,$sty)]
    set o_state   [set $BgpVar(PeerState,$sty)]
    set remote_as [set $BgpVar(PeerRemoteAs,$sty)]
    set est_time  [set $BgpVar(PeerFsmEstablishedTime,$sty)]

    if { $o_state == "established" } {
	set handled 0
	if { [info exists bgpPeerUpTime($ix)] } {
	    # Ignore session resets as a result of a restart
	    if { $uptime >= $bgpPeerUpTime($ix) } {
		if { $bgpPeerUpTime($ix) > $est_time } {
		    # peer was reset, but is now up
		    if { $localAS($sh) != $remote_as } {
			# external peer session was reset => alert
			bgpExternalReset $sh $sty $ix $vbl
			log [format "debug: Noted external reset for %s: %s" $r $ix]
			set handled 1
		    }
		}
	    }
	}
	if { ! $handled && $localAS($sh) != $remote_as } {
	    if [eventIxExists $ix bgp] {
		set eid [eventId $ix bgp]
		if { [getEventAttr $eid "bgpOS"] != "established" } {
		    bgpExternalReset $sh $sty $ix $vbl
		    log [format "debug: BGP session up for %s: %s" $r $ix]
		}
	    }
	}
    } else {
	if { $a_state == "stop" || $a_state == "halted" } {
	    if { ! [info exists bgpPeerAdminState($ix)] } {
		set bgpPeerAdminState($ix) "unknown"
	    }
	    if { $bgpPeerAdminState($ix) != $a_state } {
		# admin turned off
		bgpAdminDown $sh $sty $ix $vbl
		log [format "debug: Router %s peer %s AS %s admin-down" \
			 $r $remote $remote_as]
	    }
	} else {
	    if { ! [info exists bgpPeerAdminState($ix)] } {
		set bgpPeerAdminState($ix) "unknown"
	    }
	    if { $bgpPeerAdminState($ix) != $a_state && \
		     $localAS($sh) != $remote_as } {
		bgpAdminUp $sh $sty $ix $vbl
	    }
	    if { ! [info exists bgpPeerOperState($ix)] } {
		set bgpPeerOperState($ix) "established"
	    }
	    # peer is not up, but configured to be up
	    # Check if it's an external AS
	    if { $localAS($sh) != $remote_as && \
		 $bgpPeerOperState($ix) == "established" } {
		# First verify that we've been up more than 10 minutes
		# before we flag it as an alert
		if { $uptime > 600 } {
		    bgpOperDown $sh $sty $ix $vbl
		    log [format "debug: Router %s peer %s AS %s os %s (down)" \
			     $r $remote $remote_as $o_state]
		} else {
		    log [format "debug: Router %s peer %s AS %s is %s (down), but uptime = %d" \
			     $r $remote $remote_as $o_state $uptime]
		}
	    }
	}
    }
    set bgpPeerOperState($ix) $o_state
    set bgpPeerAdminState($ix) $a_state
    set bgpPeerUpTime($ix) $est_time

    # Possibly add to list of peers, record it as recently seen
    # to allow later garbage collection
    set found 0
    set now [clock seconds]
    if { [info exists bgpPeers($r)] } {
	foreach p $bgpPeers($r) {
	    if { $p == $remote } {
		set found 1
		set k [format "%s,%s" $r $p]
		set sawPeer($k) $now
	    }
	}
    }
    if { ! $found } {
	lappend bgpPeers($r) $remote
	set k [format "%s,%s" $r $remote]
	set sawPeer($k) $now
    }

}

proc checkBGPpeers { sh sty up } {
    global BgpVarlist
    
    set vl $BgpVarlist($sty)
    sparseWalk $sh $vl x [list eval recordBGPpeer $sh $sty $up {$x}]
}

proc checkBGP { sh } {
    global localAS
    global localAsVar
    global localAsVars
    global BgpStyle

    if { [::config::conf [name $sh] "do_bgp"] != "yes" } {
	log [format "Skipping BGP scanning for %s due to config" \
		 [name $sh]]
	return
    }

    if [info exists BgpStyle($sh)] {
#	log [format "Router %s Bgp MIB style '%s'" \
#		 [name $sh] $BgpStyle($sh)]
	$sh getnext "$localAsVar($BgpStyle($sh)) sysUpTime" {
	    # Judiciously avoid using "local" variables;
	    # the callback is executed in the global context!

	    #	puts [format "%s %s %s" %S %E "%V"]
	    if { "%E" != "noError" } {
		return
	    }
	    if { ! [info exists BgpStyle([lindex [split [mib name [lindex [lindex "%V" 0] 0]] "."] 0])] } {
		# Wrong BGP style, reset
		log [format "Router %s wrong BGP style, was '%s'" \
			 [name %S] $BgpStyle(%S)]
		log [format "Router %s get-next got %s" [name %S] \
			 [mib name [lindex [lindex "%V" 0] 0]]]
		unset BgpStyle(%S)
		return
	    }
	    if { [lindex [lindex "%V" 0] 2] == 0 } {
		# Not a BGP speaker?
		return
	    }
	    set localAS(%S) [lindex [lindex "%V" 0] 2]
	    #	puts [format "localAS(%s) %s" %S $localAS(%S)]
	    set BgpStyle(%S) $BgpStyle([lindex [split [mib name [lindex [lindex "%V" 0] 0]] "."] 0])

	    checkBGPpeers %S $BgpStyle(%S) [expr [mib scan \
		    [lindex [lindex "%V" 1] 0] \
		    [lindex [lindex "%V" 1] 2] \
		    ] / 100]
	}
	return
    }

    # BgpStyle is unknown, probe for it
    foreach var $localAsVars {
	if { [info exists BgpStyle($sh)] } {
#	    log [format "Router %s aborting probing, BgpStyle known, is '%s'" \
#		     [name $sh] $BgpStyle($sh)]
	    return
	}
#	log [format "Router %s probing via %s" [name $sh] $var]
	$sh getnext "$var sysUpTime" {
	    # Judiciously avoid using "local" variables;
	    # the callback is executed in the global context!

	    #	puts [format "%s %s %s" %S %E "%V"]
	    if { "%E" != "noError" } {
		log [format "Router %s got error %s" [name %S] "%E"]
		return
	    }

	    if { ! [info exists BgpStyle([lindex [split [mib name [lindex [lindex "%V" 0] 0]] "."] 0])] } {
		# Not one of the localAsVars prefixes...
#		log [format "Router %s get-next not AsVar" [name %S]]
#		log [format "Router %s get-next gave %s" [name %S] \
#			 [mib name [lindex [lindex "%V" 0] 0]]]
		# Wrong BGP style probed?
		return
	    }
	    if { [lindex [lindex "%V" 0] 2] == 0 } {
#		log [format "Router %s not a BGP speaker?" [name %S]]
		# Not a BGP speaker?
		return
	    }
	    set localAS(%S) [lindex [lindex "%V" 0] 2]
	    # Correctly probed BGP style MIB support, remember it
	    set BgpStyle(%S) $BgpStyle([lindex [split [mib name [lindex [lindex "%V" 0] 0]] "."] 0])
	    #	puts [format "localAS(%s) %s" %S $localAS(%S)]

#	    log [format "Router %s set to BGP style '%s'" \
#		     [name %S] $BgpStyle(%S)]

	    checkBGPpeers %S $BgpStyle(%S) [expr [mib scan \
		    [lindex [lindex "%V" 1] 0] \
		    [lindex [lindex "%V" 1] 2] \
		    ] / 100]
	}
	# Allow first request to be answered before second probe is launched
	$sh wait
    }
}
