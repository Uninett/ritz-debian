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

mib load rfc1213.mib
mib load cisco.mib


proc initDev { sh } {
}

proc destroyDev { sh } {

    forgetConfig $sh
}

proc pollDev { sh } {
    global errorInfo

#    puts [format "polling %s" [name $sh]]
    if [catch {
	# determine reachability and whether it
	# has rebooted/crashed since the last go-around
	uptimeCheck $sh
	# need to do this for each round
	# since interfaces may have been turned
	# on or cards can be hot-swapped
	getConfig $sh
	# do the walk...
	pollIntfs $sh
    } msg] {
	if [regexp "FAILED" $msg] { return; }
	puts $errorInfo
    }
}

#
# Uptime checking
#

proc uptimeCheck { sh } {
    global cx

    set uptime [getUptime $sh]
    set name [name $sh]
    if { ! [expectedUptime $name $uptime] } {
	# record timestamp for use later
	set cx($name,reload) [expr [clock seconds] - $uptime / 100]
    }
    set cx($name,lastpoll) [clock seconds]
}

proc expectedUptime { name newup } {
    global cx uptimeSlop

    if { ! [info exists cx($name,uptime)] } { return 0; }
    if { ! [info exists cx($name,lastpoll)] } { return 0; }
    set estup [expr $cx($name,uptime) + \
	    100 * ( [clock seconds] - $cx($name,lastpoll) )]
    
    if { $cx($name,uptime) == 0 } { return 0; }
    if { $newup < $estup - $uptimeSlop } { return 0; }
    return 1
}

proc getUptime { sh } {

    if { [catch {set vbl [$sh get "sysUpTime.0"]} msg] } {
	set msg [format "Uptime poll FAILED for %s: %s" [name $sh] $msg]
	logerr $msg
	error $msg
    }
    set name [lindex [lindex $vbl 0] 0]
    set value [lindex [lindex $vbl 0] 2]
    return [mib scan $name $value]
}

#
#
#

# Need to check config on each round, since interface
# cards can nowadays be hot-swapped

proc getConfig { sh } {
    global cx

    set name [name $sh]
    set cx($name,sysid) [getSysObjID $sh]
    forgetConfig $sh
    getAddrList $sh
    getIfList $sh
}

proc getSysObjID { sh } {
    if [catch {set vbl [$sh get "sysObjectID.0"]} msg] {
	set msg [format "sysObjectID poll FAILED for %s: %s" [name $sh] $msg]
	logerr $msg
	error $msg
    }
    set name  [lindex [lindex $vbl 0] 0]
    set value [lindex [lindex $vbl 0] 2]
    return [mib scan $name $value]
}

proc forgetConfig { sh } {
    global cx

    set name [name $sh]
    if [info exists cx($name,ifindexes)] {
	foreach ix $cx($name,ifindexes) {
	    catch {unset cx($name,address,$i)}
	    catch {unset cx($name,type,$i)}
	    catch {unset cx($name,speed,$i)}
	    catch {unset cx($name,admin,$i)}
	    catch {unset cx($name,descr,$i)}
	}
	unset cx($name,ifindexes)
    }
}

proc getAddrList { sh } {

    $sh walk x "ipAdEntIfIndex ipAdEntAddr" \
	    { recordAddr $sh $x }
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
    }
}

proc getIfList { sh } {
    
    # This table may be sparsely populated
    sparseTableWalk $sh x \
	    "ifIndex ifType ifSpeed ifAdminStatus ifDescr" \
	    { recordIntf $sh $x }
}

proc recordIntf { sh vbl } {
    global cx

    set ix	[lindex [lindex $vbl 0] 2]
    set type	[lindex [lindex $vbl 1] 2]
    set speed	[lindex [lindex $vbl 2] 2]
    set admin	[lindex [lindex $vbl 3] 2]
    set descr	[lindex [lindex $vbl 4] 2]
    set type [mib scan [lindex [lindex $vbl 1] 0] $type]; # undo TC coding

    set name [name $sh]

    set cx($name,type,$ix) $type
    set cx($name,speed,$ix) $speed
    set cx($name,admin,$ix) $admin
    set cx($name,descr,$ix) $descr
    lappend cx($name,ifindexes) $ix
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
	set msg [format "%s poll: %s" [name %S] %E]
	logerr $msg
#	error $msg
    }
}

proc getVarList { sh } {
    global cx

    set vl [list "ifInOctets" "ifInUcastPkts" \
	    "ifInNUcastPkts" "ifInDiscards" \
	    "ifInErrors" "ifOutOctets" \
	    "ifOutUcastPkts" "ifOutNUcastPkts" \
	    "ifOutDiscards" "ifOutErrors"]
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
	    [getNowStamp] [getStamp $cx($name,reload)]]
}

proc logInfo { fh name ix } {
    global cx

    puts $fh [format "ifSpeed %s" $cx($name,speed,$ix)]
    puts $fh [format "ifType %d"  $cx($name,type,$ix)]
    puts $fh [format "ifDescr \"%s\"" $cx($name,descr,$ix)]
}

#
#
#

proc getNowStamp {} {
    return [getStamp [clock seconds]]
}

proc getStamp { secs } {
    return [clock format $secs \
	    -format "%a %b %d %H:%M:%S %Y"]
}

proc logerr { msg } {

    # Could / should be improved to do syslog (?)
    puts stderr $msg
}

#
#
#

