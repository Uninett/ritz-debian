#
# $Id$
#

#
# Traffic statistics poller
#

namespace import ::polljob::name
namespace import ::just::sparseTableWalk
namespace import ::just::asyncSparseTableWalk
namespace import ::config::conf*

#
# This is _really_ ugly.  Ensure that rfc2863.mib is loaded prior to
# rfc1213.mib, and likewise ensure that IANAifType.tc is loaded as early as
# possible.
#
set x [lsearch -exact $tnm(mibs:core) rfc1213.mib]
if { $x >= 0 } {
    set tnm(mibs:core) [linsert $tnm(mibs:core) $x rfc2863.mib]
}

set x [lsearch -exact $tnm(mibs:core) compat.tc]
if { $x >= 0 } {
    set tnm(mibs:core) [lreplace $tnm(mibs:core) $x $x compat.tc IANAifType.tc]
}

mib load rfc2863.mib
mib load IANAifType.tc
mib load cisco.mib
mib load ../mibs/IPV6-TC.my
mib load ../mibs/IPV6-MIB.my

proc initDev { sh } {
}

proc destroyDev { sh } {

    forgetConfig $sh
}

proc pollDev { sh } {
    global errorInfo

    set dev [name $sh]
    # First check if we're to collect stats from this box
    if { [conf $dev "statistics"] != "yes" } {	return; }

#    puts [format "polling %s" [name $sh]]

    $sh get sysUpTime.0 {
	uptimeProcess "%S" "%E" "%V" pollDev_1
    }
}

proc pollDev_1 { sh } {
    
    $sh get sysObjectID.0 {
	sysobjProcess "%S" "%E" "%V" pollDev_2
    }
}

proc pollDev_2 { sh } {

    forgetConfig $sh
    bulkWalk $sh "ipAdEntIfIndex ipAdEntAddr" 10 \
	recordAddr pollDev_3 errAddr
}

proc pollDev_3 { sh } {

    set name [name $sh]

    set vl "ifIndex ifType ifSpeed ifAdminStatus ifDescr"
    if { [::config::conf $name "hcounters"] != "no" } {
	lappend vl "ifHighSpeed"
    }
    asyncSparseTableWalk $sh x $vl { recordIntf "%S" $x } \
	{ pollDev_4 "%S" } { errIntf "%S" "%E" }
}

proc pollDev_4 { sh } {

    pollIntfs $sh
}

proc errAddr { sh err } {

    set msg [format "Get address list FAILED for %s: %s" [name $sh] $err]
    logerr $msg
}

proc errIntf { sh err } {

    set msg [format "Get interface list FAILED for %s: %s" [name $sh] $err]
    logerr $msg
}

#
# Uptime checking
#

proc uptimeProcess { sh err vbl call_continue } {
    global cx

    if { $err != "noError" } {
	set msg [format "Uptime poll FAILED for %s: %s" [name $sh] $err]
	logerr $msg
	return
    }
    set varname [lindex [lindex $vbl 0] 0]
    set value [lindex [lindex $vbl 0] 2]
    set uptime [mib scan $varname $value]

    set name [name $sh]
    if { ! [expectedUptime $name $uptime] } {
	# record timestamp for use later
	set cx($name,reload) [expr [clock seconds] - $uptime / 100]
    }
    set cx($name,lastpoll) [clock seconds]

    eval $call_continue $sh
}

proc expectedUptime { name newup } {
    global cx uptimeSlop

    if { ! [info exists cx($name,uptime)] } {
	set cx($name,uptime) $newup
	return 0;
    }
    set lastuptime $cx($name,uptime)
    set cx($name,uptime) $newup

    # We don't know what to expect in this case
    if { ! [info exists cx($name,lastpoll)] } { 
	return 0;
    }

    # Estimate new expected uptime
    set now [clock seconds]
    set estup [expr $lastuptime + \
		   100 * ( $now - $cx($name,lastpoll) )]

    # 32-bit unsigned counter overflow (or too close), ignore;
    # uptime counter wraparound has happened or is imminent
    if { $estup > 0xffffffff - $uptimeSlop } {
	set msg [format \
"%s: uptime wraparound (or close), estup %s lastuptime %s lastpoll %s time %s" \
		     $name $estup $lastuptime \
		     $cx($name,lastpoll) $now]
	logerr $msg
	return 1
    }

    if { $cx($name,uptime) == 0 } { 
	return 0;
    }

    if { $newup < $estup - $uptimeSlop } {
	set msg [format \
"%s: unexpected uptime, newup %s estup %s lastuptime %s lastpoll %s time %s" \
		     $name $newup $estup \
		     $lastuptime $cx($name,lastpoll) $now]
	logerr $msg
	return 0
    }

    # Everything as expected
    return 1
}

#
#
#

# Need to check config on each round, since interface
# cards can nowadays be hot-swapped

proc sysobjProcess { sh err vbl call_continue } {
    global cx

    if { $err != "noError" } {
	set msg [format "sysObjectID poll FAILED for %s: %s" [name $sh] $err]
	logerr $msg
	return
    }
    set name  [lindex [lindex $vbl 0] 0]
    set value [lindex [lindex $vbl 0] 2]
    set sysobj [mib scan $name $value]

    set cx([name $sh],sysid) $sysobj

    eval $call_continue $sh
}

proc forgetConfig { sh } {
    global cx

    set name [name $sh]
    if [info exists cx($name,ifindexes)] {
	foreach ix $cx($name,ifindexes) {
	    catch {unset cx($name,address,$ix)}
	    catch {unset cx($name,type,$ix)}
	    catch {unset cx($name,speed,$ix)}
	    catch {unset cx($name,admin,$ix)}
	    catch {unset cx($name,descr,$ix)}
	}
	unset cx($name,ifindexes)
    }
}

proc recordAddr { sh vbl } {
    global cx

    set ix [lindex [lindex $vbl 0] 2]
    set ad [lindex [lindex $vbl 1] 2]

    set name [name $sh]
    if { ! [info exists cx($name,address,$ix)] } {
	# only remember lowest address if interface
	# has more than one
	set cx($name,address,$ix) $ad

#	puts [format "New address: %s for %s,%s" $ad $name $ix]
    }
#	puts [format "Address already seen for %s,%s: %s %s (new)" \
#		$name $ix $cx($name,address,$ix) $ad]
#
}

proc recordIntf { sh vbl } {
    global cx

    set ix	[lindex [lindex $vbl 0] 2]
    set type	[lindex [lindex $vbl 1] 2]
    set speed	[lindex [lindex $vbl 2] 2]
    set admin	[lindex [lindex $vbl 3] 2]
    set descr	[lindex [lindex $vbl 4] 2]
    set type [mib scan [lindex [lindex $vbl 1] 0] $type]; # undo TC coding
    set hs	[lindex [lindex $vbl 5] 2]

    if { $hs != "" && $hs != 0 && $hs > 3000 } {
	set speed [expr $hs * 1000000.0]
    }

    set name [name $sh]

    set s ""

    if [info exists cx($name,type,$ix)] {
	if { $cx($name,type,$ix) != $type } {
	    set s [format "IfIndex %s on %s changed type from %s to %s" \
		       $ix $name $cx($name,type,$ix) $type]
	}
    }
    set cx($name,type,$ix) $type

    if [info exists cx($name,speed,$ix)] {
	if { $cx($name,speed,$ix) != $speed } {
	    set s [format "%s\nIfIndex %s on %s changed speed from %s to %s" \
		       $s $ix $name $cx($name,speed,$ix) $speed]
	    set cx($name,speedchange,$ix) 1
	}
    }
    set cx($name,speed,$ix) $speed

    if [info exists cx($name,admin,$ix)] {
	if { $cx($name,admin,$ix) != $admin } {
	    set s [format "%s\nifIndex %s on %s changed admin-state from %s to %s" \
		       $s $ix $name $cx($name,admin,$ix) $admin]
	}
    }
    set cx($name,admin,$ix) $admin

    if [info exists cx($name,descr,$ix)] {
	if { $cx($name,descr,$ix) != $descr } {
	    set s [format "%s\nifIndex %s on %s changed descr from \"%s\" to \"%s\"" \
		       $s $ix $name $cx($name,descr,$ix) $descr]
	}
    }
    set cx($name,descr,$ix) $descr
    lappend cx($name,ifindexes) $ix

    if { $s != "" } {
	logerr $s
    }

#    puts [format "Intf %s,%s type %s speed %s admin %s descr %s" \
#	    $name $ix $type $speed $admin $descr]
}

#
#
#

proc pollIntfs { sh } {

    set vl [getVarList $sh]
    asyncSparseTableWalk $sh x $vl {
	logVars %S $x
    } {
	# no endscript
#	puts [format "finished polling %s" [name %S]]
    } {
	logerr [format "%s poll FAILED: %s" [name %S] %E]
    }
}

proc getVarList { sh } {
    global cx

    set name [::polljob::name $sh]

    set vl [list "ifInUcastPkts" "ifInNUcastPkts" "ifInDiscards" \
		"ifInErrors" "ifOutUcastPkts" "ifOutNUcastPkts" \
		"ifOutDiscards" "ifOutErrors" \
		"ifInMulticastPkts" "ifOutMulticastPkts" \
		"ifInBroadcastPkts" "ifOutBroadcastPkts" \
		"ipv6IfStatsInReceives" "ipv6IfStatsOutForwDatagrams" \
	       ]

    if { [::config::conf $name "hcounters"] != "no" } {
	lappend vl "ifHCInOctets" "ifHCOutOctets"
    }
    lappend vl "ifInOctets" "ifOutOctets"

    if { [oidPfxMatch [mib oid cisco] $cx([name $sh],sysid)] } {
	lappend vl "locIfInRunts" "locIfInGiants" \
		"locIfInCRC" "locIfInFrame" \
		"locIfInOverrun" "locIfInIgnored" \
		"locIfInAbort" "locIfResets" \
		"locIfRestarts" "locIfCollisions"
    }
    return $vl
}

proc oidPfxMatch { a b } {
    append a "."
    set ix [string first $a $b]
    return [expr $ix == 0]
}

proc logVars { sh vbl } {
    global cx

    set stamp [getNowStamp]
    set name [name $sh]

    foreach vb $vbl {
	set oid [lindex $vb 0]
	if { $oid != {} } {
	    set ix [getInstance $oid]
	}
    }
    if { ! [info exists ix] } { return; }

    if { ! [info exists cx($name,descr,$ix)] &&
	 ! [info exists cx($name,admin,$ix)] } {
	return;				# mostly-non-existent ifIndex
	# old Cisco MIB might return vars for locIf*
    }

    if [confExists $name "watchpat"] {
	set wp [conf $name "watchpat"]
	# Only poll ports matching pattern
	if { ! [regexp $wp $cx($name,descr,$ix)] } { return; }
    }
    if [confExists $name "ignorepat"] {
	set ign [conf $name "ignorepat"]
	# Ignore ports we've been instructed to ignore
	if [regexp $ign $cx($name,descr,$ix)] { return; }
    }
    # Ignore interfaces not turned on
    if { $cx($name,admin,$ix) != "up" } { return; }

    set fh [openFile $name $ix newfile]
    # Log files rotated daily, so log interface
    # information first and close to the end of the day
    if { $newfile || [almostMidnight]} {
	logInfo $fh $name $ix
    }

    # if the device was reloaded
    # and we've not yet recorded it, do so now
    maybeLogReload $fh $name $ix

    if [ info exists cx($name,speedchange,$ix) ] {
	logInfo $fh $name $ix
	unset cx($name,speedchange,$ix)
    }

    foreach vb $vbl {
	set oid [lindex $vb 0]
	# skip nonexistent table entries
	if { $oid == {} } { continue; }

	set vn [mib name $oid]
	puts $fh [format "%s %s %s" $stamp $vn [lindex $vb 2]]
    }

    close $fh
}

proc getInstance { oid } {
    return [join [lrange [split [mib name $oid] "."] 1 end] "."]
}

proc openFile { dev ix new } {
    upvar $new New

    set fn [getFileName $dev $ix]
    set New [expr ! [file exists $fn]]
    if [catch {set fh [open $fn "a"]} msg] {
	logerr [format "%s open error: %s" $fn $msg]
	error $msg
    }
    return $fh
}

proc getFileName { dev ix } {
    global cx LogDir

    if { [info exists cx($dev,address,$ix)] } {
	set aPart $cx($dev,address,$ix)
    } else {
	set aPart [format "#%d" $ix]
    }
    return [format "%s/%s.%s" $LogDir $dev $aPart]
}

proc almostMidnight {} {

    set s [clock seconds]
    set h [clock format $s -format "%H"]
    set m [clock format $s -format "%M"]
    if { $h == 23 && $m >= 35 } {
	return 1
    }
    return 0
}

proc maybeLogReload { fh name ix } {
    global cx

    if [info exists cx($name,reload)] {
	if [info exists cx($name,reload,$ix)] {
	    if { $cx($name,reload) != $cx($name,reload,$ix) } {
		logReload $fh $name
		set cx($name,reload,$ix) $cx($name,reload); # mark as logged
	    }
	} else {
	    logReload $fh $name
	    set cx($name,reload,$ix) $cx($name,reload)
	}
    }
}

proc logReload { fh name } {
    global cx

    puts $fh [format "%s Reboot at %s" \
	    [getNowStamp] $cx($name,reload)]
}

proc logInfo { fh name ix } {
    global cx

    puts $fh [format "Version 1"]
    puts $fh [format "ifSpeed %s" $cx($name,speed,$ix)]
    puts $fh [format "ifType %d"  $cx($name,type,$ix)]
    puts $fh [format "ifDescr \"%s\"" $cx($name,descr,$ix)]
}

#
#
#

proc getNowStamp {} {
    return [clock seconds]
}

proc dateNowStamp { } {
    return [clock format [clock seconds] \
	    -format "%a %b %d %H:%M:%S %Y"]
    
}

proc logerr { msg } {

    # Could / should be improved to do syslog (?)
    puts stderr [format "%s: %s" [dateNowStamp] $msg]
}

#
#
#

