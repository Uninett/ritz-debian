#
# $Id$
#
# Handling of traps.
#
# linkUp/Down traps trigger an interface state poll.
#



proc initTrap { } {

    setupTrapListeners
    ::persist::add ::BootTime
}

proc setupTrapListeners { } {
    global v1TrapHandle v2TrapHandle

    if [info exists v1TrapHandle] {
        log "destroying v1TrapHandle"
        if { [catch { $v1TrapHandle destroy } errmsg] } {
            log [format "v1TrapHandle destroy returned %s" $errmsg]
        }
    }
    if [info exists v2TrapHandle] {
        log "destroying v2TrapHandle"
        if { [catch { $v2TrapHandle destroy } errmsg] } {
            log [format "v2TrapHandle destroy returned %s" $errmsg]
        }
    }

    set v1TrapHandle [snmp session]
    $v1TrapHandle bind {} trap { doTrap %A %T %V }
    $v1TrapHandle bind {} inform { doInform %A %T %V }
    
    set v2TrapHandle [snmp session -version SNMPv2c]
    $v2TrapHandle bind {} inform { doInform %A %T %V }
    $v2TrapHandle bind {} trap { doTrap %A %T %V }
}

proc TrapWatchdog { } {
    global TotalTraps
    global LastTrap
    global Restarting
    global twjob
    
    set now [clock seconds]

    $twjob configure -iterations 1000; # keep us running indefinately

        # If no trap received for 5 minutes, destroy & reconnect
    # ...unless we try and fail three times in a row; clearly
    # if that's the case the re-open action isn't working.

    if { [expr $now - $LastTrap] < [expr 5 * 60] } {
        log [format "debug: TrapWatchdog: traps OK; %d total" \
                 $TotalTraps]
        set TotalTraps 0
        set Restarting 0
        return
    }

    if { $Restarting > 3 } {
        log "TrapWatchdog: already restarting, to no effect, not retrying!"
    }

    log "TrapWatchdog: No SNMP traps received for > 5 minutes, re-enabling"
    set Restarting [expr $Restarting + 1]

    setupTrapListeners
}

set TotalTraps 0
set Restarting 0
set LastTrap [clock seconds];	# initialize

# Let the trap watchdog run every minute
set twjob [job create \
               -command TrapWatchdog \
               -interval [expr 1000 * 60] \
               -iterations 1000]


proc doInform { a type args } {

    doTrap $a $type $args
}

proc hexToIP4 { v } {
    set l [split $v ":"]
    set v [format "%d.%d.%d.%d" \
	       0x[lindex $l 0] \
	       0x[lindex $l 1] \
	       0x[lindex $l 2] \
	       0x[lindex $l 3]]
    return $v
}

proc hexToIP6 { v } {
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

    foreach sub ":0:0:0:0:0:0:0 :0:0:0:0:0:0 :0:0:0:0:0 :0:0:0:0 :0:0:0 :0:0" {
	if {[regsub $sub $s ":" s] != 0} {
	    return $s
	}
    }

    return $s
}

proc doTrap { a type args } {
    global AddrToRouter
    global RestartTime
    global portToIfDescr
    global bgpPeerOperState
    global TotalTraps
    global LastTrap
    global BootTime

    set TotalTraps [expr $TotalTraps + 1]
    set LastTrap [clock seconds]

    if { ! [info exists AddrToRouter($a)] } {
	puts [format "ignored trap from %s (not a box we monitor?)" $a]
	return
    }
    if [catch { set sh [handle $AddrToRouter($a)] }] {
	puts [format "ignored trap from %s (startup?)" $a]
	return
    }
    set r [name $sh]
#    set r $AddrToRouter($a)

#    puts [format "%s: trap-type %s" $r $type]

    foreach vb $args {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set fn [mib name $oid]
	set ol [split [mib name $oid] "."]
	set var [lrange $ol 0 0]
	set $var $val
	set instance($var) [join [lrange $ol 1 end] "."]

#	puts [format "%s: var %s value %s" $r $fn $val]

    }

    if { ! [info exists snmpTrapOID] } {
	puts [format "snmpTrapOID missing from %s (%s)" $r $a]
	return
    }

    # Tweak for SNMPv1 traps, they appear to have an "extra" 0 in the OID...
    if { $type == "snmpV1-trap" } {
	switch -regexp $snmpTrapOID {
	    ^[0-9.]*$ {
		set oidlist [split [mib name $snmpTrapOID] "."]
		if { [lrange $oidlist 1 1] == 0 } {
		    set inst [format "%s.%s" \
				  [lrange $oidlist 0 0] \
				  [join [lrange $oidlist 2 end] "."]]
		    set snmpTrapOID [mib name [mib oid $inst]]
		} else {
		    set snmpTrapOID [mib name $snmpTrapOID]
		}
	    }
	}
    }

    if { [info exists sysUpTime] } {
	set uptime [mib scan sysUpTime.0 $sysUpTime]
	if [info exists BootTime($r)] {
	    set trap_time [expr $BootTime($r) + $uptime / 100]
	    set now $LastTrap
	    set tdiff [expr $now - $trap_time]
	    if { [expr abs($tdiff)] > 1 } {
		log [format "debug: %s trap time-diff %s" $r $tdiff]
	    }
	}
    } else {
	puts [format "sysUpTime not part of trap"]
	return
    }

    set router $r
    # Hmm, inaccurate for queued trap messages which are transmitted
    # a bit later.  Would be better to use BootTime($r)
    set RestartTime($router) [expr [clock seconds] - ($uptime / 100)]

    switch $snmpTrapOID {
	IF-MIB!linkUp {
	    set s [format "%s: linkUp" $r]
	    if { ! [info exists ifIndex] } {
		set ifIndex -1
	    }
	    if { ! [info exists ifDescr] } {
		if { [info exists portToIfDescr($r,$ifIndex)] } {
		    set ifDescr $portToIfDescr($r,$ifIndex)
		} else {
		    set ifDescr "unknown"
		}
	    }
	    if { ! [info exists locIfReason] } {
		set locIfReason ""
	    }
	    linkTrans $router $ifIndex $ifDescr Up $locIfReason
	}
	IF-MIB!linkDown {
	    set s [format "%s: linkDown" $r]
	    if { ! [info exists ifIndex] } {
		set ifIndex -1
	    }
	    if { ! [info exists ifDescr] } {
		if { [info exists portToIfDescr($r,$ifIndex)] } {
		    set ifDescr $portToIfDescr($r,$ifIndex)
		} else {
		    set ifDescr "unknown"
		}
	    }
	    if { ! [info exists locIfReason] } {
		set locIfReason ""
	    }
	    linkTrans $router $ifIndex $ifDescr Down $locIfReason
	}
	SNMPv2-MIB!coldStart {
	    log [format "%s: coldStart" $router]
	}
	SNMPv2-MIB!warmStart {
	    log [format "%s: warmStart" $router]
	}
	CISCOTRAP-MIB!reload {
	    log [format "%s: reload requested" $router]
	}
	bgpBackwardTransition {
	    # has to do something...
	    set s glorp
	}
	BGP4-MIB!bgpBackwardTransition {
	    # has to do something...
	    set s glorp
	}
	BGP4-MIB!bgpBackwardTransNotification {
	    # has to do something...
	    set s glorp
	}
	BFD-STD-MIB!bfdSessUp {
	    doBFDtrap $r up $args
	}
	BFD-STD-MIB!bfdSessDown {
	    doBFDtrap $r down $args
	}
	jnxBgpM2Experiment.1.1.0.2 {
	    # Ignore for now ...
	    # has to do something...
	    set s glorp
	}
	SNMPv2-MIB!authenticationFailure {
	    # has to do something...
	    set s glorp
#	    puts [format "%s: auth-failure" $router]
#	    log [format "%s: auth-failure" $router]
	}
	CISCO-CONFIG-MAN-MIB!ciscoConfigManEvent {
	    log [format "%s: config-change: cmd-src %s conf-src %s dst %s" \
		    $r $ccmHistoryEventCommandSource \
		    $ccmHistoryEventConfigSource \
		    $ccmHistoryEventConfigDestination]
	}
	CISCO-PIM-MIB!ciscoPimInvalidRegister {
	    set s [format "%s PIM-invalid-register:" [name $sh]]
	    if { ! [info exists cpimLastErrorOriginType] } {
		break
	    }
	    if { $cpimLastErrorOriginType != "ipv4" } {
		break
	    }
	    set o [hexToIP4 $cpimLastErrorOrigin]
	    set g [hexToIP4 $cpimLastErrorGroup]
	    set rp [hexToIP4 $cpimLastErrorRP]

	    set s [format "%s from %s group %s RP %s" $s $o $g $rp]

#	    foreach vb $args {
#		set oid [lindex $vb 0]
#		set val [lindex $vb 2]
#		set name [mib name $oid]
#		set s [format "%s\n  %s = %s" $s $name $val]
#	    }
	    log $s
	}

	CISCO-PIM-MIB!ciscoPimInvalidJoinPrune {
	    set s [format "%s PIM-invalid-join-prune:" [name $sh]]
	    if { ! [info exists cpimLastErrorOriginType] } {
		return
	    }
	    if { $cpimLastErrorOriginType != "ipv4" } {
		return		
	    }
	    set o [hexToIP4 $cpimLastErrorOrigin]
	    set g [hexToIP4 $cpimLastErrorGroup]
	    set rp [hexToIP4 $cpimLastErrorRP]

	    set s [format "%s from %s group %s RP %s" $s $o $g $rp]
	    log $s
	}

	BGP4-V2-MIB-JUNIPER!jnxBgpM2BackwardTransition {
	    set s [format "%s Lost BGP peer:" [name $sh]]

	    if { ! [info exists jnxBgpM2PeerLocalAddrType] } {
		return
	    }
	    if { $jnxBgpM2PeerLocalAddrType != "ipv4" } {
		set peer [hexToIP6 $jnxBgpM2PeerRemoteAddr]
	    } else {
		set peer [hexToIP4 $jnxBgpM2PeerRemoteAddr]
	    }
	    set state $jnxBgpM2PeerState
	    set ix [format "%s,%s" [name $sh] $peer]

	    if [info exists bgpPeerOperState($ix)] {
		set prev_state $bgpPeerOperState($ix)
	    } else {
		set prev_state "unknown"
	    }

	    if { $state != "established" && \
		 $prev_state == "established" } {
		set s [format "%s %s state %s" $s $peer $state]
		log $s
	    }
	    set bgpPeerOperState($ix) $state
	}

	BGP4-V2-MIB-JUNIPER!jnxBgpM2Established {
	    set s [format "%s BGP peer up:" [name $sh]]

	    if { ! [info exists jnxBgpM2PeerRemoteAddrType]} {
		return
	    }
	    if { $jnxBgpM2PeerRemoteAddrType != "ipv4" } {
		set peer [hexToIP6 $jnxBgpM2PeerRemoteAddr]
	    } else {
		set peer [hexToIP4 $jnxBgpM2PeerRemoteAddr]
	    }
	    set state $jnxBgpM2PeerState

	    set s [format "%s %s state %s" $s $peer $state]
	    log $s
	}

	CISCOTRAP-MIB!tcpConnectionClose {
#	    if { ! [info exists instance(loctcpConnElapsed)] } {
#		log [format "%s: no loctcpConnElapsed!" $router]
#		puts "Dump of local variables:"
#		foreach var [info locals] {
#		    if { [array exists $var] } {
#			puts [format "  array: %s" $var]
#			foreach ix [lsort [array names $var]] {
#			    puts [format "    %s: %s" $ix [set [set var]($ix)]]
#			}
#		    } else {
#			if { [info exists $var] } {
#			    puts [format "  %s: %s" $var [set $var]]
#			} else {
#			    puts [format "  %s does not exist" $var]
#			}
#		    }
#		}
#		return
#	    }
	    set from [join \
		    [lrange [split $instance(loctcpConnElapsed) "."] \
		    5 8] "."]
# Don't log these anymore
#	    log [format "%s: %s logout (via %s from %s) after %s" \
#		    $router $tsLineUser \
#		    $tslineSesType $from $loctcpConnElapsed]
	}
#	1.3.6.1.2.1.15.0.1 { # bgpEstablished
#	    log [format "%s: bgp established with %s" $router \
#		    $instance(bgpPeerState)]
#	}
#	1.3.6.1.2.1.15.0.2 { # bgpBackwardTransition
#	    log [format "%s: bgp loss with %s, state %s" $router \
#		    $instance(bgpPeerState) $bgpPeerState ]
#	}
	ospfIfConfigError {
	    # Log all the local variables internalized above matching ospf*
	    log [format "%s: trap %s" $router $snmpTrapOID]
	    set vl ""
	    foreach v [info locals] {
		if [regexp "^ospf" $v] {
		    lappend vl $v
		}
	    }
	    foreach v $vl {
		log [format "%s: trap-var %s: %s" $router $v [set $v]]
	    }
	}
	BGP4-V2-MIB-JUNIPER!jnxBgpM2BackwardTransition {
	    # Ignore, we're already doing delayed BGP polling
	    # has to do something...
	    set s glorp
	}
	default {
	    log [format "%s: unknown trap: %s (%s)" \
		    $router $snmpTrapOID \
		    [mib name $snmpTrapOID]]
	}
    }
    if [eventIxExists $router "reachability"] {
	# We got a trap from the box -- check if it's now reachable
	checkResponse $sh
    }
}

proc os_to_as { os } {
    set l [split $os :]
    set as ""
    foreach c $l {
	scan $c "%x" ac
	set as [format "%s%c" $as $ac]
    }
    return $as
}

