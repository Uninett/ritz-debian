#
# $Id$
#

proc log { msg } {

    set ts [clock format [clock seconds] -format "%a %b %d %H:%M:%S %Y"]
    puts [format "%s: %s" $ts $msg]
}

proc inc { var } {
    upvar $var v
    if { ! [info exists v] } {
	set v 0
    }
    set v [expr $v + 1]
}

proc decodeAddr { at a } {

    if { $at == "ipv6" } {
	set al [split $a ":"]
	set as [format "%s%s:%s%s:%s%s:%s%s:%s%s:%s%s:%s%s:%s%s" \
		    [lindex $al 0] \
		    [lindex $al 1] \
		    [lindex $al 2] \
		    [lindex $al 3] \
		    [lindex $al 4] \
		    [lindex $al 5] \
		    [lindex $al 6] \
		    [lindex $al 7] \
		    [lindex $al 8] \
		    [lindex $al 9] \
		    [lindex $al 10] \
		    [lindex $al 11] \
		    [lindex $al 12] \
		    [lindex $al 13] \
		    [lindex $al 14] \
		    [lindex $al 15]]
	# Replace all 0000 with just 0
	regsub -all "0000" $as "0" as
	# Replace all leading 0s followed by non-zero and non-colon
	regsub -all ":0+(\[^0:\]+)" $as ":\\1" as
	# To lower-case
	set as [string tolower $as]
	# Replace longest string of 0's with just ::
        foreach sub \
                ":0:0:0:0:0:0:0 :0:0:0:0:0:0 :0:0:0:0:0 :0:0:0:0 :0:0:0 :0:0" \
                {
            if {[regsub $sub $as ":" as] != 0} {
                return $as
            }
        }
	return $as

    } elseif { $at == "ipv4" } {
	set al [split $a ":"]
	set as [format "%d.%d.%d.%d" \
		    [expr [format "%x%s" [lindex $al 0]]] \
		    [expr [format "%x%s" [lindex $al 1]]] \
		    [expr [format "%x%s" [lindex $al 2]]] \
		    [expr [format "%x%s" [lindex $al 3]]]]
	return $as

    } else {
	log [format "Unrecognized address-type: %s" $at]
    }
    return ""
}

proc nameFor { at as } {

    if { $at == "ipv6" } {
	if { [catch {
	    set rs [exec host $as]
	} result options] } {
	    return ""
	}
	set fqdn [lindex $rs 4]
	# chop off final dot
	set n [string range $fqdn 0 end-1]
	return $n
    } else {
	if { [catch {
	    set n [dns name $as]
	}] } {
	    return ""
	}
	return $n
    }
}

proc unqualName { a } {

    if { [catch {
	set n [dns name $a]
    }] } {
	return ""
    }
    set nl [split $n "."]
    set un [lindex $nl 0]

    set sl [lindex $nl 1]
    set tl [lindex $nl 2]

    if { $sl == "uninett" && $tl == "no" && [llength $nl] == 3 } {
	return $un
    } else {
	return ""
    }
}

proc managedDevice { a } {
    global AddrToRouter

    if { ! [info exists AddrToRouter($a)] } {
	return 0
    }
    return 1
}

proc routerName { a } {
    global AddrToRouter

    if { [info exists AddrToRouter($a)] } {
	return $AddrToRouter($a)
    }
    error "No known name for address"
}


proc ifDescr { a ix } {
    global portToIfDescr

    if { [catch { set r [routerName $a] } msg ] } {
	log [format "%s: %s" $a $msg]
    }
    if { [info exists portToIfDescr($r,$ix)] } {
	return $portToIfDescr($r,$ix)
    }
    return ""
}

proc ifAlias { a ix } {
    global portToLocIfDescr

    if { [catch { set r [routerName $a] } msg ] } {
	log [format "%s: %s" $a $msg]
    }
    if { [info exists portToLocIfDescr($r,$ix)] } {
	return $portToLocIfDescr($r,$ix)
    }
    return ""
}

proc logicalName { alias } {
    set i [string first ", " $alias]
    if { $i == -1 } {
#	puts "first ', ' not found"
	return "unknown"
    }
    set alias [string range $alias [expr $i + 2] end]
    set i [string first ", " $alias]
    if { $i == -1 } {
#	puts "second ', ' not found"
	set ln $alias
    } else {
	set ln [string range $alias 0 [expr $i - 1]]
    }
    set ln [string trimleft $ln]
    set ln [string trimright $ln]
    return $ln
}

proc logLinkTrans { type a ix descr alias } {

    set s ""
    if { $descr eq "" } {
	set descr "unknown"
    }
    if { $alias eq "" } {
	set alias "unknown"
    }
    set logical [logicalName $alias]

    # Create log entry in json format
    set s "{"
    set s [format "%s\"timestamp\":%s" $s [expr [clock milliseconds] / 1000.0]]
    set s [format "%s,\"trap_source\":%s" $s $a]
    set s [format "%s,\"name\":\"%s\"" $s [nameFor ipv4 $a]]
    set s [format "%s,\"trap_type\":\"%s\"" $s $type]
    set s [format "%s,\"ifIndex\":%s" $s $ix]
    set s [format "%s,\"ifDescr\":\"%s\"" $s $descr]
    set s [format "%s,\"ifAlias\":\"%s\"" $s $alias]
    set s [format "%s,\"logical_name\":\"%s\"" $s $logical]
    set s [format "%s}" $s]

    # Let's re-open for each logged line
    # Allows easy log file rotation
    set logFile [open "link-traps.log" "a"]
    puts $logFile $s
    flush $logFile
    close $logFile
}

proc doInform { a type args } {
    
    log [format "%s: inform message" $a]
    doTrap $a $type $args
}

proc doTrap { a type args } {
    global LastTrap
    global TotalTraps

    set LastTrap [clock seconds]; # note that we received one, for "keepalive"
    inc TotalTraps

    foreach vb $args {
        set oid [lindex $vb 0]
        set val [lindex $vb 2]
        set fn [mib name $oid]
        set ol [split [mib name $oid] "."]
        set var [lrange $ol 0 0]
        set $var $val
        set instance($var) [join [lrange $ol 1 end] "."]

#       puts [format "%s: var %s value %s" $a $fn $val]

    }

    unset oid
    unset val
    unset fn
    unset ol
    unset var
    
#    log [format "%s: trap %s message received" $a $type]

    if { ! [info exists snmpTrapOID] } {
        puts [format "snmpTrapOID missing from %s" $a]
        return
    }

#    log [format "%s: past check for snmpTrapOID" $a]

    # Tweak for SNMPv1 traps, they appear to have an "extra" 0 in the OID...
    if { $type == "snmpV1-trap" } {
        switch -regexp $snmpTrapOID {
            ^[0-9.]*$ {
                set oidlist [split [mib name $snmpTrapOID] "."]
		if { [lrange $oidlist 0 0] != "iso" && \
			 [lrange $oidlist 2 2] != 8802 } {
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
    }

    if { [info exists sysUpTime] } {
        set uptime [mib scan sysUpTime.0 $sysUpTime]
    } else {
        puts [format "sysUpTime not part of trap from %s" $a]
        return
    }

#    log [format "%s: past check for sysUpTime" $a]

    if {! [managedDevice $a] } {
#	log [format "trap from non-managed device: %s / %s" \
#		 $a [nameFor ipv4 $a]]
	return; # just ignore
    }

    switch $snmpTrapOID {

	# These are the ones we're mostly concerned about
	# and which we log for:
	IF-MIB!linkDown {
	    if { ! [info exists ifDescr] } {
		set ifdescr [ifDescr $a $ifIndex]
	    } else {
		set ifdescr $ifDescr
	    }
	    set ifalias [ifAlias $a $ifIndex]
	    
	    log [format "%s: linkDown ifIndex %s (%s) (%s) (%s)" $a \
		     $ifIndex $ifdescr $ifalias [nameFor ipv4 $a]]

	    logLinkTrans linkDown $a $ifIndex $ifdescr $ifalias

	    set s ""
	    foreach vn [info locals] {
		if { ! [array exists $vn] && \
			 $vn != "s" && \
			 $vn != "args" } {
		    set s [format "%s\t%s: %s\n" $s $vn [set $vn]]
		}
	    }
	    log $s
	}
	IF-MIB!linkUp {
	    if { ! [info exists ifDescr] } {
		set ifdescr [ifDescr $a $ifIndex]
	    } else {
		set ifdescr $ifDescr
	    }
	    set ifalias [ifAlias $a $ifIndex]
	    
	    log [format "%s: linkUp ifIndex %s (%s) (%s) (%s)" $a \
		     $ifIndex $ifdescr $ifalias [nameFor ipv4 $a]]

	    logLinkTrans linkUp $a $ifIndex $ifdescr $ifalias

	    set s ""
	    foreach vn [info locals] {
		if { ! [array exists $vn] && \
			 $vn != "s" && \
			 $vn != "args" } {
		    set s [format "%s\t%s: %s\n" $s $vn [set $vn]]
		}
	    }
	    log $s
	}


	# might be interesting, log a bit of information on stdout
	# (but not for log forwarding):

	CISCO-IF-EXTENSION-MIB!cieLinkDown {
	    log [format "%s: cisco LinkDown (os %s as %s) for %s on %s" $a \
		     $ifOperStatus $ifAdminStatus \
		     $ifName [nameFor ipv4 $a]]
	}
	CISCO-IF-EXTENSION-MIB!cieLinkUp {
	    log [format "%s: cisco LinkUp %s on %s" $a \
		     $ifName [nameFor ipv4 $a]]
	}
	CISCO-IF-EXTENSION-MIB!cieDelayedLinkUpDownNotif {
	    log [format "%s: cisco up/down (os %s as %s) for %s cause %s on %s" \
		     $a \
		     $ifOperStatus $ifAdminStatus \
		     $ifName $cieIfOperStatusCause \
		     [nameFor ipv4 $a]]
	}
	JUNIPER-VPN-MIB!jnxVpnPwUp {
	    log [format "%s: VPN pseudowire up, type %s" $a $jnxVpnPwVpnType]
	}
	JUNIPER-VPN-MIB!jnxVpnIfDown {
	    log [format "%s: VPN interface down, type %s" $a $jnxVpnIfVpnType]
	}

	BFD-STD-MIB!bfdSessUp {
	    log [format "%s: BFD session up on %s" $a \
		     [nameFor ipv4 $a]]
	}
	BFD-STD-MIB!bfdSessDown {
	    log [format "%s: BFD session down on %s" $a \
		     [nameFor ipv4 $a]]
	}
	CISCO-IETF-BFD-MIB!ciscoBfdSessUp {
	    log [format "%s: BFD session up (on %s)" $a \
		     [nameFor ipv4 $a]]
	}
	CISCO-IETF-BFD-MIB!ciscoBfdSessDown {
	    log [format "%s: BFD session down (on %s)" $a \
		     [nameFor ipv4 $a]]
	}

	JUNIPER-DOM-MIB!jnxDomAlarmSet {
	    log [format "%s: DOM alarm set: was %s now %s (on %s / %s)" \
		     $a \
		     $jnxDomLastAlarms \
		     $jnxDomCurrentAlarms \
		     $ifDescr [nameFor ipv4 $a]]
	}
	JUNIPER-DOM-MIB!jnxDomAlarmCleared {
	    log [format "%s: DOM alarm cleared: was %s now %s (on %s / %s)" \
		     $a \
		     $jnxDomLastAlarms \
		     $jnxDomCurrentAlarms \
		     $ifDescr [nameFor ipv4 $a]]
	}
	JUNIPER-DOM-MIB!jnxDomLaneAlarmSet {
	    log [format "%s: DOM lane alarm set: %s (on %s / %s)" \
		     $a \
		     $jnxDomLaneLastAlarms \
		     $ifDescr [nameFor ipv4 $a]]
	}
	JUNIPER-DOM-MIB!jnxDomLaneAlarmCleared {
	    log [format "%s: DOM lane alarm cleared: %s (on %s / %s)" \
		     $a \
		     $jnxDomLaneLastAlarms \
		     $ifDescr [nameFor ipv4 $a]]
	}

	ISIS-MIB!isisDatabaseOverload {
	    log [format "%s: ISIS database overload %s (on %s)" \
		     $isisSysLevelState \
		     $a [nameFor ipv4 $a]]
	}
	ISIS-MIB!isisAdjacencyChange {
	    log [format "%s: ISIS adjacency change (on %s)" \
		     $a [nameFor ipv4 $a]]
	    set s ""
	    foreach vn [info locals] {
		if { ! [array exists $vn] && \
			 $vn != "s" && \
			 $vn != "args" } {
		    set s [format "%s\t%s: %s\n" $s $vn [set $vn]]
		}
	    }
	    log $s
	}
	ISIS-MIB!isisRejectedAdjacency {
	    log [format "%s: ISIS adjacency rejection (on %s)" \
		     $a [nameFor ipv4 $a]]
	    set s ""
	    foreach vn [info locals] {
		if { ! [array exists $vn] && \
			 $vn != "s" && \
			 $vn != "args" } {
		    set s [format "%s\t%s: %s\n" $s $vn [set $vn]]
		}
	    }
	    log $s
	}
	ISIS-MIB!isisProtocolsSupportedMismatch {
	    log [format "%s: ISIS protocol support mismatch (on %s)" \
		     $a [nameFor ipv4 $a]]
	    set s ""
	    foreach vn [info locals] {
		if { ! [array exists $vn] && \
			 $vn != "s" && \
			 $vn != "args" } {
		    set s [format "%s\t%s: %s\n" $s $vn [set $vn]]
		}
	    }
	    log $s
	}
	ISIS-MIB!isisAuthenticationTypeFailure {
	    log [format "%s: ISIS authentication failure (on %s)" \
		     $a [nameFor ipv4 $a]]
	    set s ""
	    foreach vn [info locals] {
		if { ! [array exists $vn] && \
			 $vn != "s" && \
			 $vn != "args" } {
		    set s [format "%s\t%s: %s\n" $s $vn [set $vn]]
		}
	    }
	    log $s
	}

	default {
# here we just ignore otherwise-unknown trap messages:
#
#	    log [format "%s: unknown trap: %s (%s)" \
#		     $a $snmpTrapOID \
#		     [mib name $snmpTrapOID]]
#	    set s ""
#	    foreach vn [info locals] {
#		if { ! [array exists $vn] && \
#			 $vn != "s" && \
#			 $vn != "args" } {
#		    set s [format "%s\t%s: %s\n" $s $vn [set $vn]]
#		}
#	    }
#	    log $s
	}
    }
#    log [format "%s: past switch" $a]
}

# save-state.tcl contains variables in this namespace,
# avoid problems caused by that...
namespace eval ::pm {
}

proc reReadZinoState { } {
    global readStateJob

    set f "%TOPDIR%/zino/save-state.tcl"

    if { [catch { source $f } msg] } {
	log [format "Error reading %s: %s" $f $msg]
    }

    $readStateJob configure -iterations 1000; # keep running indefinately
}


set readStateJob [job create \
		      -command reReadZinoState \
		      -interval [expr 1000 * 60] \
		      -iterations 1000]


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
    global LastTrap
    global twjob
    global TotalTraps
    global Retarting

    set now [clock seconds]

#    log "TrapWatchdog: running"

    $twjob configure -iterations 1000; # keep us running indefinately

    # If no trap received for 5 minutes, destroy & reconnect
    # ...unless we try and fail three times in a row; clearly
    # if that's the case the re-open action isn't working.

    if { [expr $now - $LastTrap] < [expr 5 * 60] } {
	log [format "TrapWatchdog: traps OK; %d total" \
		 $TotalTraps]
	set TotalTraps 0
	set Restarting 0
	return
    }

    if { $Restarting > 3 } {
	log "TrapWatchdog: already restarting, to no effect, aborting!"
	exit 1
    }

    log "TrapWatchdog: No SNMP traps received for > 5 minutes, re-enabling"
    inc Restarting

    setupTrapListeners

}


# Main

# initialize...
set LastTrap [clock seconds]
set TotalTraps 0
set Restarting 0

puts "listening for traps"

setupTrapListeners

puts "bind to trap and inform done"

# Let the trap watchdog run every minute
set twjob [job create \
	       -command TrapWatchdog \
	       -interval [expr 1000 * 60] \
	       -iterations 1000]

puts "trap watchdog started"
