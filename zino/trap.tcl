#
# $Id$
#
# Handling of traps.
#
# linkUp/Down traps trigger an interface state poll.
#

proc initTrap { } {
    global s

    set s [snmp session]
    catch { $s bind {} trap { doTrap %A %T %V } }
    sleep 5
    $s bind {} trap { doTrap %A %T %V }
}

proc doTrap { a type args } {
    global AddrToRouter cx
    global RestartTime

    if { ! [info exists AddrToRouter($a)] } {
	puts [format "ignored trap from %s" $a]
	return
    }
    set sh $cx($AddrToRouter($a),handle)

#    puts [format "%s: trap-type %s" $cx($sh,name) $type]
    foreach vb $args {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set ol [split [mib name $oid] "."]
	set var [lrange $ol 0 0]
	set $var $val
	set instance($var) [join [lrange $ol 1 end] "."]
#	puts [format "%s: %s %s instance %s" \
#		$cx($sh,name) $var $val $instance($var)]
    }
    if { [info exists sysUpTime] } {
	set uptime [mib scan sysUpTime.0 $sysUpTime]
    } else {
	puts [format "sysUpTime not part of trap"]
	return
    }
    if { ! [info exists snmpTrapOID] } {
	puts [format "snmpTrapOID missing from %s (%s)" $cx($sh,name) $a]
	return
    }

    set router $cx($sh,name)
    set RestartTime($router) [expr [clock seconds] - ($uptime / 100)]

    switch $snmpTrapOID {
	IF-MIB!linkUp {
	    set s [format "%s: linkUp" $cx($sh,name)]
	    if { ! [info exists ifIndex] } {
		set ifIndex -1
	    }
	    if { ! [info exists ifDescr] } {
		set ifDescr "unknown"
	    }
	    if { ! [info exists locIfReason] } {
		set locIfReason ""
	    }
	    linkTrans $router $ifIndex $ifDescr Up $locIfReason
	}
	IF-MIB!linkDown {
	    set s [format "%s: linkDown" $cx($sh,name)]
	    if { ! [info exists ifIndex] } {
		set ifIndex -1
	    }
	    if { ! [info exists ifDescr] } {
		set ifDescr "unknown"
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
	SNMPv2-MIB!authenticationFailure {
	    # has to do something...
	    set s glorp
#	    puts [format "%s: auth-failure" $router]
#	    log [format "%s: auth-failure" $router]
	}
	CISCO-CONFIG-MAN-MIB!ciscoConfigManEvent {
	    log [format "%s: config-change: cmd-src %s conf-src %s dst %s" \
		    $cx($sh,name) $ccmHistoryEventCommandSource \
		    $ccmHistoryEventConfigSource \
		    $ccmHistoryEventConfigDestination]
	}
	CISCOTRAP-MIB!tcpConnectionClose {
	    if { ! [info exists instance(loctcpConnElapsed)] } {
		log [format "%s: no loctcpConnElapsed!" $router]
		puts "Dump of local variables:"
		foreach var [info locals] {
		    if { [array exists $var] } {
			puts [format "  array: %s" $var]
			foreach ix [lsort [array names $var]] {
			    puts [format "    %s: %s" $ix [set [set var]($ix)]]
			}
		    } else {
			if { [info exists $var] } {
			    puts [format "  %s: %s" $var [set $var]]
			} else {
			    puts [format "  %s does not exist" $var]
			}
		    }
		}
		return
	    }
	    set from [join \
		    [lrange [split $instance(loctcpConnElapsed) "."] \
		    5 8] "."]
	    # specal hack while Olav Kvittem collects VC statistics
	    if { $tsLineUser == "up" } { return; }
	    log [format "%s: %s logout (via %s from %s) after %s" \
		    $router $tsLineUser \
		    $tslineSesType $from $loctcpConnElapsed]
	}
	1.3.6.1.2.1.15.0.1 { # bgpEstablished
	    log [format "%s: bgp established with %s" $router \
		    $instance(bgpPeerState)]
	}
	1.3.6.1.2.1.15.0.2 { # bgpBackwardTransition
	    log [format "%s: bgp loss with %s, state %s" $router \
		    $instance(bgpPeerState) $bgpPeerState ]
	}
	default {
	    log [format "%s: unknown trap: %s" $router $snmpTrapOID]
	    puts "Dump of local variables:"
	    foreach var [info locals] {
		if { [array exists $var] } {
		    puts [format "  array: %s" $var]
		    foreach ix [lsort [array names $var]] {
			puts [format "    %s: %s" $ix [set [set var]($ix)]]
		    }
		} else {
		    if { [info exists $var] } {
			puts [format "  %s: %s" $var [set $var]]
		    } else {
			puts [format "  %s does not exist" $var]
		    }
		}
	    }
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

