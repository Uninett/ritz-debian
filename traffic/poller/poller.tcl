#!%SCOTTY%
#
# $Id$
#

# Copyright (c) 1996, 1997
#      UNINETT and NORDUnet.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#      This product includes software developed by UNINETT and NORDUnet.
# 4. Neither the name of UNINETT or NORDUnet nor the names
#    of its contributors may be used to endorse or promote
#    products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY UNINETT AND NORDUnet ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL UNINETT OR NORDUnet OR
# THEIR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

#
# Poll routers for traffic counters.  Poll Cisco routers
# for more counters.
#

# TODO:
#	More configurable getVarList?

proc recordAddr { sh vbl } {
    global cx
    set ixVbl [lindex $vbl 0]
    set adVbl [lindex $vbl 1]
    set ix [lindex $ixVbl 2]
    set ad [lindex $adVbl 2]
#   puts [format "Ix %s, address %s" $ix $ad]
    if { ! [info exists cx($sh,address,$ix)] } {# only remembers lowest address
	set cx($sh,address,$ix) $ad
    }
}

# Get current list of IP addresses
# How do we handle and report errors/timeouts here?

proc getAddrList { sh } {
    $sh walk x "ipAdEntIfIndex ipAdEntAddr" \
	    { recordAddr $sh $x }
}

proc recordIntf { sh vbl } {
    global cx
    set ix	[lindex [lindex $vbl 0] 2]
    set type	[lindex [lindex $vbl 1] 2]
    set speed	[lindex [lindex $vbl 2] 2]
    set admin	[lindex [lindex $vbl 3] 2]
    set descr	[lindex [lindex $vbl 4] 2]
    set type [mib scan [lindex [lindex $vbl 1] 0] $type]; # undo TC coding
    set cx($sh,type,$ix) $type
    set cx($sh,speed,$ix) $speed
    set cx($sh,admin,$ix) $admin
    set cx($sh,descr,$ix) $descr
#   puts [format "Ix %s, type %s, speed %s, admin %s, descr %s" \
#	    $ix $type $speed $admin $descr]
}


# Get list of interfaces and their state, speed, type, description
# How do we handle and report errors/timeouts here?

proc getIfList { sh } {
    $sh walk x \
	    "ifIndex ifType ifSpeed ifAdminStatus ifDescr" \
	    { recordIntf $sh $x }
}

proc getSysID { sh } {
    if { [catch {set svbl [$sh get "sysObjectID.0"]}] == 1} {
	return ""
    }
    set name  [lindex [lindex $svbl 0] 0]
    set value [lindex [lindex $svbl 0] 2]
    return [mib scan $name $value]
}

# This one does it's work synchronously
# (caused by "snmp# walk" operations in subroutines)

proc configCheck { sh } {
    global cx newid
#puts [format "Checking config of %s" $cx($sh,name)]
    # Get sysObjectID
    set id [getSysID $sh]
    if { $id == "" } { return 0 }
    set cx($sh,sysid) $id
    # Forget old settings
    # This assumes that the ifDescr column is densely populated
    for { set i 1 } { [info exists cx($sh,descr,$i)] } { incr i } {
	catch {unset cx($sh,address,$i)}
	catch {unset cx($sh,type,$i)}
	catch {unset cx($sh,speed,$i)}
	catch {unset cx($sh,admin,$i)}
	catch {unset cx($sh,descr,$i)}
    }
    # Get new settings, protect against time-outs
    if { [catch {getAddrList $sh}] == 1 } { return 0 }
    if { [catch {getIfList $sh}] == 1 } { return 0 }
    return 1
}

proc compareOID { oid1 oid2 } {
    set list1 [split $oid1 .]
    set list2 [split $oid2 .]
    foreach {el1} $list1 {el2} $list2 {
	if { [expr [string length "$el1"] == 0 || \
		[string length "$el2"] == 0] } {
	    if { [string length "$el1"] == 0 } {
		return -1;
	    } else {
		return 1;
	    }
	} elseif { $el1 < $el2 } {
	    return -1;
	} elseif { $el1 > $el2 } {
	    return 1;
	}
    }
    return 0;
}

proc getInstance { oid } {
    return [join [lrange [split [mib name $oid] "."] 1 end] "."]
}

proc getInstance_2 { oid root } {
    set ix [expr 1 + [string length $root]]
    return [string range $oid $ix end]
}

proc oidPfxMatch { a b } {
    append a "."
    set ix [string first $a $b]
    return [expr $ix == 0]
}

proc getMatchingInstance { Void Soid inst } {
    upvar $inst instance
    if { [oidPfxMatch $Soid $Void] } {
	set instance [getInstance_2 $Void $Soid]
	return 1
    }
    return 0
}

proc getLowestMatch { slist vbl } {
    if { [llength slist] != [llength vbl]} {
	return
    }
    set li 0
    for {set i 0} {$i < [llength $slist]} {incr i} {
	set soid [lindex $slist $i]
	set velt [lindex $vbl $i]
	set void [lindex $velt 0]
	if { [getMatchingInstance $void $soid inst] } {
	    if { $li == 0 || [compareOID $inst $li] == -1} {
		set li $inst
	    }
	}
    }
    return $li
}

proc filterLowestMatching { slist li vbl } {
    set newList ""
    for {set i 0} {$i < [llength $slist]} {incr i} {
	set soid [lindex $slist $i]
	set velt [lindex $vbl $i]
	set void [lindex $velt 0]
	if { [getMatchingInstance $void $soid inst] } {
	    if { [string compare $inst $li] == 0 } {
		lappend newList $velt
	    }
	}
    }
    return $newList
}

proc processRow { sh vbl err slist var action } {
    global cx
    if { $err == "noError" } {
	set li [getLowestMatch $slist $vbl]
	set vbl [filterLowestMatching $slist $li $vbl]
	if { [string compare "" $vbl] == 0 } {
	    return;		# no matches, end of table
	}
	set $var $vbl
	eval $action
	foreach elt $slist {
	    lappend nslist [format "%s.%s" $elt $li]
	}
	$sh getnext $nslist \
		[concat processRow "%S" {"%V"} "%E" \
		[list $slist] $var [list $action]]
    } else {
	logerr [format "SNMP error for %s: %s" $cx($sh,name) $err]
    }
}

proc sparseWalk { sh startList x action } {
    foreach v $startList {
	lappend oidsl [mib oid $v]
    }
    $sh getnext $oidsl \
	    [concat processRow "%S" {"%V"} "%E" \
	    [list $oidsl] $x [list $action]]
    return
}

# Omit time zone, otherwise as default

proc getStamp {} {
    return [clock format [clock seconds] -format "%a %b %d %H:%M:%S %Y"]
}

proc logerr { str } {
    set stamp [getStamp]
    puts stderr [format "%s: %s" $stamp $str]
}

proc getFileName { sh inst } {
    global cx LogDir
    set rtr $cx($sh,name)
    if { [info exists cx($sh,address,$inst)] } {
	set aPart $cx($sh,address,$inst)
    } else {
	set aPart [format "#%d" $inst]
    }
    return [format "%s/%s.%s" $LogDir $rtr $aPart]
}

proc logInfo { fh sh inst } {
    global cx
    puts $fh [format "ifSpeed %s" $cx($sh,speed,$inst)]
    puts $fh [format "ifType %d"  $cx($sh,type,$inst)]
    puts $fh [format "ifDescr \"%s\"" $cx($sh,descr,$inst)]
}

proc logReload { fh sh } {
    global cx
    puts $fh [format "%s Reboot at %s" \
	    [getStamp] [clock format $cx($sh,reload) \
	    -format "%a %b %d %H:%M:%S %Y"]]
}

proc logVars { sh vbl } {
    global cx
    set inst [getInstance [lindex [lindex $vbl 0] 0]]
    set fn [getFileName $sh $inst]
    set stamp [getStamp]
    # Does this variable exist?  If not, re-check config and retry,
    # and if it doesn't exist at that time, complain and return
    if { ! [info exists cx($sh,admin,$inst)] } {
	configCheck $sh
	if { ! [info exists cx($sh,admin,$inst)] } {
	    logerr \
     [format "Admin-state for instance %d of %s unknown!" $inst $cx($sh,name)]
	    return
	}
    }
    # Ignore interfaces not in admin "up" state
    if { $cx($sh,admin,$inst) != "up" } { return }
    # Ignore open error -- try again later.
    # Should probably be done better...
    set exists [file exists $fn]
    if { [catch { set file [open $fn "a"]}] == 1 } {
#	puts "File open error..."
	return
    }
    if { ! $exists } {
	logInfo $file $sh $inst
    } else {
	# Log the config information right before midnight as well
	set h [clock format [clock seconds] -format "%H"]
	set m [clock format [clock seconds] -format "%M"]
	if { $h == 23 && $m >= 35 } {
	    logInfo $file $sh $inst
	}
    }
    if { [info exists cx($sh,reload)] } {
	if { [info exists cx($sh,reload,$inst)] } {
	    if { $cx($sh,reload) != $cx($sh,reload,$inst) } {
		logReload $file $sh
		set cx($sh,reload,$inst) $cx($sh,reload); # mark as logged
	    }
	} else {
	    logReload $file $sh
	    set cx($sh,reload,$inst) $cx($sh,reload); # mark as logged
	}
    }
    foreach vb $vbl {
	set vn [mib name [lindex $vb 0]]
	puts $file [format "%s %s %s" $stamp $vn [lindex $vb 2]]
    }
    close $file
}

proc getUptime { sh } {
    global cx
    if { [catch {set uvbl [$sh get "sysUpTime.0"]}] == 1} {
	logerr [format "Uptime poll FAILED for %s" $cx($sh,name)]
	return 0
    }
    set name [lindex [lindex $uvbl 0] 0]
    set value [lindex [lindex $uvbl 0] 2]
#puts [format "%s uptime %s" $cx($sh,name) $value]
    return [mib scan $name $value]
}

proc getVarList { sh } {
    global cx
    set vl [list "ifInOctets" "ifInUcastPkts" \
	    "ifInNUcastPkts" "ifInDiscards" \
	    "ifInErrors" "ifOutOctets" \
	    "ifOutUcastPkts" "ifOutNUcastPkts" \
	    "ifOutDiscards" "ifOutErrors"]
    if { [oidPfxMatch [mib oid cisco] $cx($sh,sysid)] } {
	lappend vl "locIfInRunts" "locIfInGiants" \
		"locIfInCRC" "locIfInFrame" \
		"locIfInOverrun" "locIfInIgnored" \
		"locIfInAbort" "locIfResets" \
		"locIfRestarts" "locIfCollisions"
    }
    return $vl
}

# Return the index of the lowest-numbered interface which was detected
# as administratively up at last config check.  If no such port can
# be found (e.g. through missing config info), just return 1 -- this
# will force a config check if the corresponding log file doesn't exist.

proc getLowestUpIx { sh } {
    global cx
    for {set i 1} {[info exists cx($sh,admin,$i)]} {incr i} {
	if { $cx($sh,admin,$i) == "up" } {
	    return $i
	}
    }
    return 1;			# the best we can do for now...
}
    
# Poll a single router.  First check it's uptime and log file to see
# if we need to re-get the configuration.

proc pollRouter { sh } {
    global cx
    set uptime [getUptime $sh]
    if { $uptime == 0 } { return }; # timeout?  Try again later.
    if { ! [info exists cx($sh,uptime)] } {
	set cx($sh,uptime) $uptime
    }
    if { $cx($sh,uptime) >= $uptime } {# rebooted (or uninit)?
	if { $cx($sh,uptime) > $uptime } {# Really rebooted
	    set cx($sh,reload) \
		    [expr [clock seconds] - $uptime / 100]; # Record time stamp
	}
	if { ! [configCheck $sh] } {
	    logerr [format "Config check of %s FAILED" $cx($sh,name)]
	    return;		# didn't work, try again later
	}
    } else {
	set ix [getLowestUpIx $sh]
	set fn [getFileName $sh $ix]
	set exists [file exists $fn]
	if { ! $exists } {
	    if { ! [configCheck $sh] } {
		logerr [format "Config check of %s FAILED" $cx($sh,name)]
		return;		# didn't work, try again later
	    }
	    # Check the config right before midnight as well
	    set h [clock format [clock seconds] -format "%H"]
	    set m [clock format [clock seconds] -format "%M"]
	    if { $h == 23 && $m >= 35 } {
		if { ! [configCheck $sh] } {
		    logerr [format "Config check of %s FAILED" $cx($sh,name)]
		    return;		# didn't work, try again later
		}
	    }
	}
    }
    set varList [getVarList $sh]
    # This one's tricky -- I want to expand $sh but not $x at this
    # point, whereas I need to expand it when the expression is 
    # evaluated.  Thus, I need to force expansion twice, and I
    # do this by adding a second "eval" here (the other one is inside
    # processRow above).  I'm sure there's a better way to do this, but
    # I can't think of it and this one works...
    sparseWalk $sh $varList x [list eval logVars $sh {$x}]
}

# Read config file.
# Stash result in various globals.
# For the time being we ignore the "ignore" statements (deprecate?).

proc readConfig { fileName } {
    global RouterAddress Community DefaultCommunity
    global LogDir Interval Rtr_Interval
    set f [open $fileName]
    set inside 0
    while {[gets $f line] >= 0} {
	if { $inside == 0 } {
	    if {[regexp -nocase {router +([a-z0-9-]+) *\{} \
		    $line whole router]} {
		set inside 1
# puts [format "router %s" $router]
	    } elseif {[regexp "default-community\[ \t\]+\"(\[^\"\]*)\"" \
		    $line whole com] || \
		    [regexp \
		    "default-community\[ \t\]+(\[A-Za-z/\]\[^ \n\t;\]*)" \
		    $line whole com]} {
		set DefaultCommunity $com
# puts [format "default-community %s" $com]
	    } elseif {[regexp "logdir\[ \t\]+\"(\[^\"\]*)\"" \
		    $line whole dir] || \
		    [regexp "logdir\[ \t\]+(\[A-Za-z/\]\[^ \n\t;\]*)" \
		    $line whole dir]} {
		set LogDir $dir
# puts [format "logdir %s" $dir]
	    } elseif {[regexp "interval\[ \t\]+(\[0-9\]+)" \
		    $line whole intv]} {
		set Interval [expr $intv * 60 * 1000];# in ms
	    }
	} else {		# Inside
	    if {[regexp -nocase "polladdr\[ \t\]+(\[0-9.\]+);" \
		    $line whole raddr]} {
		set RouterAddress($router) $raddr
# puts [format "address %s" $raddr]
	    } elseif {[regexp "community\[ \t\]+\"(\[^\"\]*)\"" \
		    $line whole com] || \
		    [regexp "community\[ \t\]+(\[A-Za-z/\]\[^ \t\n;\]*)" \
		    $line whole com]} {
		set Community($router) $com
	    } elseif {[regexp "interval\[ \t\]+(\[0-9\]+)" \
		    $line whole intv]} {
# puts [format "Rtr-specific interval, rtr %s: %s" $router $intv]
		set Rtr_Interval($router) [expr $intv * 60 * 1000];# in ms
	    } elseif {[regexp "\};" $line]} {
		set inside 0
	    }
	}
    }
}

proc schedulePoll { sh } {
    global cx Interval Rtr_Interval
    set router $cx($sh,name)
    if {[info exists Rtr_Interval($router)]} {
	set intv $Rtr_Interval($router)
    } else {
	set intv $Interval
    }
# puts [format "Router %s interval %d" $router $intv]
    job create -interval $intv -command [list pollRouter $sh]
}

proc scheduleAll { } {
    global RouterAddress Community DefaultCommunity LogDir Interval
    global schedulingNow cx Rtr_Interval
    if { $schedulingNow } { return }
    set schedulingNow 1
    set nrouters [array size RouterAddress]
    set rtr_intv [expr $Interval/$nrouters]
    set delta 0
    foreach router [array names RouterAddress] {
	set name $router
	set ip   $RouterAddress($router)
	if { [info exists Community($router)] } {
	    set com $Community($router)
	} else {
	    set com $DefaultCommunity
	}
	set code [catch {snmp session -address $ip -community $com \
	    -timeout 30 -retries 5} s];# Be a bit less agressive
	if {$code} {
	    logerr "snmp session failed for router $name"
	    exit
	}
	set cx($s,name) $router
	if {[info exists Rtr_Interval($router)]} {
	    # Start it sooner than others, so that we don't wait
	    # too long before starting polling.
	    # The division by 1000 is to avoid overflow...
	    set mydelta [expr $Rtr_Interval($router) * \
		    ($delta/1000)/($Interval/1000)]
# puts [format "Router %s mydelta %d" $router $mydelta]
	    after $mydelta "schedulePoll $s"
	} else {
# puts [format "Router %s delta %d" $router $delta]
	    after $delta "schedulePoll $s"
	}
	set delta [expr $delta + $rtr_intv]
    }
    set schedulingNow 0
}

proc checkConfFile { } {
    global confCheckJob confFile lastMod RouterAddress
    file stat $confFile st
    if { ! [info exists lastMod] } {
	set lastMod $st(mtime)
	return
    }
    if { $st(mtime) != $lastMod } {
	set lastMod $st(mtime)
	unset RouterAddress
	readConfig $confFile
	foreach job [job info] {
	    if { $job != $confCheckJob } {
		$job destroy
	    }
	}
	scheduleAll
    }
}

proc scheduleCheckJob {} {
    global confCheckJob Interval
    set confCheckJob [job create -interval $Interval -command checkConfFile]
}

#
# Main
#

set schedulingNow 0

source %TOPDIR%/conf/config.tcl; # load mibs, set confFile, "cd" to root...

readConfig $confFile
scheduleAll
scheduleCheckJob
