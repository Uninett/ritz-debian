package provide mib2util 0.0

catch { namespace delete ::mib2util }

namespace eval ::mib2util {
    namespace import ::just::fetchTable ::just::sparseTableWalk 
    namespace import ::just::mapNames ::just::getDNSCachedName
    namespace import ::just::getCachedServiceName
    namespace import ::prettySNMP::*
    namespace export netstat routestat

    variable pfxLen

    proc initStuff { } {
	variable pfxLen
	for {set i 8; set j 1} {$i >= 0} {incr i -1; set j [expr $j * 2]} {
	    set pfxLen([expr 256 - $j]) $i
	}
    }

    proc netstat {{agentargs {}} {opts {}} {put puts}} {
	set code [catch {eval snmp session $agentargs} sh]
	if {$code} {
	    catch {eval $put {"Command failed.  Reason: $sh"}}
	    return
	}
	set all 0
	set header 1
	set kilobits 0
	set notrans 0
	set func netstat_i
	foreach flag $opts {
	    switch -- $flag {
		listAll {set all 1}
		noHeader {set header 0}
		macAddress {set func netstat_m}
		ciscoDescr {set func netstat_D}
		kilobits {set kilobits 1}
		noTranslation {set notrans 1}
	    }
	}
	set code [catch {$func $sh $all $header $put} err]
	$sh destroy
	if { $code } {
	    catch {eval $put {"Command failed. Reason: $err"}}
	}
    }

    proc netstat_i { sh all hdr put } {
	set fmt "%-2s %-19.19s %3s %4s %-15.15s %-15.15s %9s %5s"
        if { $hdr == 1 } {
	    eval $put {[format $fmt "Ix" "Name" "as" "os" "Address" \
		    "Netmask" "Type" "MTU"]}
	}

	# First, fetch all the IP-addresses of this agent.
	
	set ipVarList {ipAdEntAddr ipAdEntIfIndex ipAdEntNetMask}
	set ipVarOIDs [mapNames $ipVarList]
	foreach v $ipVarList o $ipVarOIDs {
	    set [set v]OID $o
	}
	set ipTabIxs [fetchTable $sh ipAddrTab $ipVarOIDs]
	set ifVarList [mapNames {ifIndex ifDescr ifAdminStatus \
		ifOperStatus ifType ifMtu}]
	sparseTableWalk $sh x $ifVarList {
		set ifix    [lindex        [lindex $x 0] 2]
	    set ifDescr [prettyIfDescr [lindex [lindex $x 1] 2]]
	    set ifAs    [prettyIfAs    [lindex [lindex $x 2] 2]]
	    set ifOs    [prettyIfOs    [lindex [lindex $x 3] 2]]
	    set ifType  [prettyIfType  [lindex [lindex $x 4] 2]]
	    set ifMtu   [prettyMTU     [lindex [lindex $x 5] 2]]
	    set noIpAddress 1
	    foreach ipix $ipTabIxs {
		if { $ipAddrTab($ipix,$ipAdEntIfIndexOID) == $ifix } {
		    set noIpAddress 0
		    set ipAddr "none"
		    if {[ info exists ipAddrTab($ipix,$ipAdEntAddrOID)] } {
			set ipAddr $ipAddrTab($ipix,$ipAdEntAddrOID)
		    }
		    set ipNetMask "none"
		    if { [info exists \
			    ipAddrTab($ipix,$ipAdEntNetMaskOID)] } {
			set ipNetMask $ipAddrTab($ipix,$ipAdEntNetMaskOID)
		    }
		    eval $put {[format $fmt \
			    $ifix $ifDescr $ifAs $ifOs \
			    $ipAddr $ipNetMask \
			    $ifType $ifMtu ]}
		    if { $all != 0 } break
		}
	    }
	    if { $noIpAddress } {
		eval $put {[format $fmt \
			$ifix $ifDescr $ifAs $ifOs \
			"none" "none" \
			$ifType $ifMtu ]}
	    }
	}
    }

    proc netstat_m { sh all hdr put } {
	set fmt "%-2s %-19.19s %-15.15s %-17.17s %6s %9s %5s"
        if { $hdr == 1 } {
	    eval $put {[format $fmt \
		    "Ix" "Name" "Address" "Physaddr" "Speed" "Type" "MTU"]}
	}

	set ipVarList {ipAdEntAddr ipAdEntIfIndex}
	set ipVarOIDs [mapNames $ipVarList]
	set ipTabIxs [fetchTable $sh ipAddrTab $ipVarOIDs]

	set ifVarList {ifIndex ifDescr ifType ifMtu ifSpeed ifPhysAddress}
	set ifVarOIDs [mapNames $ifVarList]
	foreach v [concat $ipVarList $ifVarList] \
		o [concat $ipVarOIDs $ifVarOIDs] {
	    set [set v]OID $o
	}
	sparseTableWalk $sh x $ifVarList {
	    set ifix       [lindex [lindex $x 0] 2]
	    set ifDescr    [prettyIfDescr [lindex [lindex $x 1] 2]]
	    set ifType     [prettyIfType [lindex [lindex $x 2] 2]]
	    set ifMtu      [prettyMTU [lindex [lindex $x 3] 2]]
	    set ifSpeed    [prettyIfSpeed [lindex [lindex $x 4] 2]]
	    set ifPhysAddr [string tolower \
		    [lindex [lindex $x 5] 2]]
	    if { "$ifPhysAddr" == "" } { set ifPhysAddr "(null)" }
	    set noIpAddress 1
	    foreach ipix $ipTabIxs {
		if { $ipAddrTab($ipix,$ipAdEntIfIndexOID) == $ifix } {
		    set noIpAddress 0
		    set ipAddr "none"
		    if {[ info exists ipAddrTab($ipix,$ipAdEntAddrOID)] } {
			set ipAddr $ipAddrTab($ipix,$ipAdEntAddrOID)
		    }
		    eval $put {[format $fmt \
			    $ifix $ifDescr $ipAddr $ifPhysAddr \
			    $ifSpeed $ifType $ifMtu]}
		    if { $all == 0 } break
		}
	    }
	    if { $noIpAddress } {
		eval $put {[format $fmt \
			$ifix $ifDescr "none" $ifPhysAddr \
			$ifSpeed $ifType $ifMtu]}
	    }
	}
    }

    proc netstat_D { sh all hdr put } {
	mib load cisco.mib
	set fmt "%-2s %-12.12s %-15.15s %6s \"%s\""
        if { $hdr == 1 } {
	    eval $put {[format "%2s %-12.12s %-15.15s %6s %s" "Ix" "Name" \
		    "Address" "Speed" "Descr"]}
	}
	# First, fetch all the IP-addresses of this agent.
	set ipVarList {ipAdEntAddr ipAdEntIfIndex ipAdEntNetMask}

	set ipVarOIDs [mapNames $ipVarList]
	set ipTabIxs [fetchTable $sh ipAddrTab $ipVarOIDs]

	set ifVarList {ifIndex ifDescr ifSpeed}
	set ifVarOIDs [mapNames $ifVarList]
	set ifTabIxs [fetchTable $sh ifTab $ifVarOIDs]

	set lifVarList {locIfDescr}
	set lifVarOIDs [mapNames $lifVarList]
	set lifTabIxs [fetchTable $sh lifTab $lifVarOIDs]
	foreach v [concat $ipVarList $ifVarList $lifVarList] \
		o [concat $ipVarOIDs $ifVarOIDs $lifVarOIDs] {
	    set [set v]OID $o
	}

	foreach ifix $ifTabIxs {
	    set ifDescr [prettyIfDescr $ifTab($ifix,$ifDescrOID)]
	    set ifSpeed [prettyIfSpeed $ifTab($ifix,$ifSpeedOID)]
	    if { [info exists lifTab($ifix,$locIfDescrOID) ] } {
		set lifDescr $lifTab($ifix,$locIfDescrOID)
	    } else {
		set lifDescr "(nil)"
	    }
	    set noIpAddress 1
	    foreach ipix $ipTabIxs {
		if { $ipAddrTab($ipix,$ipAdEntIfIndexOID) == $ifix } {
		    set noIpAddress 0
		    set ipAddr "none"
		    if {[ info exists ipAddrTab($ipix,$ipAdEntAddrOID)] } {
			set ipAddr $ipAddrTab($ipix,$ipAdEntAddrOID)
		    }
		    eval $put {[format $fmt \
			    $ifix $ifDescr $ipAddr $ifSpeed $lifDescr ]}
		    if { $all == 0 } break
		}
	    }
	    if { $noIpAddress } {
		eval $put {[format $fmt $ifix $ifDescr "none" $ifSpeed \
			$lifDescr]}
	    }
	}
    }

    proc routestat {{snmpargs {}} {opts {}} {put puts}} {
	set code [catch {eval snmp session $snmpargs} sh]
	if {$code} {
	    catch {eval $put {"Could not create SNMP handle; $sh"}}
	    return
	}
	set count 0x7fffffff
	set prefix ""
	set newOpts {}
	foreach opt $opts {
	    switch -glob -- $opt {
		noHeader {lappend newOpts $opt}
		noTranslation {lappend newOpts $opt}
		{prefix [0-9]*}  {set prefix [lindex $opt 1]}
		{count [-0-9]*} {set count [lindex $opt 1]}
		default { puts "unknown option $opt" }
	    }
	}
	lappend newOpts [list prefix $prefix]
	lappend newOpts [list count $count]

	set code [catch {getRouteTable $sh $newOpts $put} err]
	$sh destroy
	if {$code} {
	    catch {eval $put {"Command failed: $err"}}
	}
    }

    proc printRouteTableEntry { fmt ifTab vbl notrans put } {
	upvar $ifTab tab
	variable pfxLen

	set varList {ipRouteDest ipRouteMask ipRouteNextHop \
		ipRouteType ipRouteIfIndex ipRouteProto}
	foreach v $varList vb $vbl {
	    set $v [lindex $vb 2]
	}

	set len 0
	set comps [split $ipRouteMask .]
	foreach c $comps {
	    if {[info exists pfxLen($c)]} {
		incr len $pfxLen($c)
	    } else {
		set len "??"
		break
	    }
	}

	set flags "U"
	if       { $ipRouteType == "indirect" } {
	    set flags "UG"
	} elseif { $ipRouteType == "invalid" } {
	    set flags ""
	} 
	if { $ipRouteProto == "local" } {
	    set ipRouteProto "local/static"
	}
	if { $len == 32 } {
	    append flags H
	}
	if { [info exists tab($ipRouteIfIndex,ifDescr) ] } {
	    set descr $tab($ipRouteIfIndex,ifDescr)
	} else {
	    set descr "if($ipRouteIfIndex)"
	}
	if { $notrans == 0 } {
	    set ipRouteNextHop [getDNSCachedName $ipRouteNextHop]
	}

	eval $put {[format $fmt "$ipRouteDest/$len" $ipRouteNextHop $flags \
		$descr $ipRouteProto]}
	return 0
    }

    proc getRouteTable { sh opts put } {
	set fmt "%-22s%-23s%-6s%-16s%-8s"
	set comps {}
	if { [lsearch $opts noHeader] == -1 } {
	    eval $put {[format $fmt "Destination (pfx/len)" "Gateway" "Flags" \
		    "Interface" "Protocol"]}
	}
	
	set ixs [fetchTable $sh ifTab "ifDescr"]
	foreach ix $ixs {
	    if {[info exists ifTab($ix,ifDescr)]} {
		set ifTab($ix,ifDescr) [prettyIfDescr $ifTab($ix,ifDescr)]
	    } else {
		set ifTab($ix,ifDescr) "if($ix)"
	    }
	}
	
	set prefix [lindex [lindex $opts [lsearch $opts {prefix *}]] 1]
	set prefix [string trim $prefix .]
	if { ![regexp {^[0-9.]*$} $prefix dummy] } {
	    eval $put {"$prefix is not an IP-prefix"}
	    return
	}
	foreach el [split $prefix .] {
	    lappend comps [expr $el % 256]
	}

	if { [llength $comps] > 0 } {
	    set postfix .[join $comps .]
	} else {
	    set postfix ""
	}
	set notrans [expr [lsearch $opts noTranslation] != -1]
	set ix [lsearch $opts {count *}]
	set cnt [lindex [lindex $opts $ix] 1]
	set cnt [expr $cnt == -1 ? 0x7fffffff : $cnt]

	set varList [list ipRouteDest$postfix ipRouteMask$postfix \
		ipRouteNextHop$postfix ipRouteType$postfix \
		ipRouteIfIndex$postfix ipRouteProto$postfix ]

	if { [llength $comps] == 4 } {
	    # This is a request for a single specific route.  It's not
	    # practical to use the 'walk' operation here.
	    set varList [$sh get $varList]
	    printRouteTableEntry $fmt ifTab $varList $notrans $put
	    return
	} 
	#
	# The route prefix is not a dotted quad, i.e. it's shorter.
	# Start walking
	#
	sparseTableWalk $sh x $varList {
	    printRouteTableEntry $fmt ifTab $x $notrans $put
	    incr cnt -1
	    if { $cnt <= 0 } {
		return
	    }
	}
    }

    proc activestat {{snmpargs {}} {opts {}} {put puts}} {
	set code [catch {eval snmp session $snmpargs} sh]
	if {$code} {
	    catch {eval $put {"Could not create SNMP handle; $sh"}}
	    return
	}
	set code [catch {getAStats $sh $opts $put} err]
	$sh destroy
	if {$code} {
	    catch {eval $put {"Command failed: $err"}}
	}
    }

    proc getAStats { sh opts put } {
	set fmt "%-4s%24.24s.%-6.6s %24.24s.%-6.6s %s"
	if { [lsearch $opts noHeader] == -1 } {
	    eval $put {[format "Proto%29s%30s    State" "Local address" \
		    "Remote address"]}
	}
	set vbl {tcpConnLocalAddress tcpConnLocalPort \
		tcpConnRemAddress tcpConnRemPort tcpConnState}
	set trans [expr [lsearch $opts noTranslation] == -1]
	$sh walk x $vbl {
	    foreach v  {locAddr locPort remAddr remPort state} \
		    vb $x {
		set $v [lindex $vb 2]
	    }
	    if { $trans } {
		set locAddr [getDNSCachedName $locAddr]
		set remAddr [getDNSCachedName $remAddr]
		set locPort [getCachedServiceName $locPort tcp]
		set remPort [getCachedServiceName $remPort tcp]
	    }
	    eval $put {[format $fmt tcp $locAddr $locPort $remAddr \
		    $remPort $state]}
	}
	
	set fmt "%-4s%24.24s.%-6.6s %31s %s"
	set vbl {udpLocalAddress udpLocalPort}
	$sh walk x $vbl {
	    set locAddr [lindex [lindex $x 0] 2]
	    set locPort [lindex [lindex $x 1] 2]
	    if { $trans } {
		set locAddr [getDNSCachedName $locAddr]
		set locPort [getCachedServiceName $locPort udp]
	    }
	    eval $put {[format $fmt udp $locAddr $locPort "" listening]}
	}
    }

    initStuff
}
