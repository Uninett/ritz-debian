#
# $Id$
#

proc initJNXalarm {} {

    ::persist::add ::JNXalarms
}

proc JNXalarm { r colour old_count new_count } {

    set ix [format "%s,%s" $r $colour]
    set old [eventIxExists $ix alarm]
    set eid [eventId $ix alarm]

    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "alarm-type" $colour
    setEventAttr $eid "alarm-count" $new_count

    set l [format "alarms went from %s to %s" $old_count $new_count]
    setEventAttr $eid "lastevent" $l

    set s [format "%s %s %s" $r $colour $l]
    log $s
    eventLog $eid $s

    eventCommit $eid
}

proc recordJNXalarms { sh vbl } {
    global JNXalarms
    global lastPoll

    set lastPoll($sh) [clock seconds]
    foreach vb $vbl {
	set oid [lindex $vb 0]
	set val [lindex $vb 2]
	set var [lrange [split [mib name $oid] "."] 0 0]
	set $var $val
    }
    set r [name $sh]

    foreach c {yellow red} {
	if { ! [info exists JNXalarms($r,$c)] } {
	    set JNXalarms($r,$c) 0
	}
    }
    if { $jnxYellowAlarmCount != $JNXalarms($r,yellow) } {
	JNXalarm $r yellow $JNXalarms($r,yellow) $jnxYellowAlarmCount
	set JNXalarms($r,yellow) $jnxYellowAlarmCount
    }
    if { $jnxRedAlarmCount != $JNXalarms($r,red) } {
	JNXalarm $r "red" $JNXalarms($r,red) $jnxRedAlarmCount
	set JNXalarms($r,red) $jnxRedAlarmCount
    }
}

proc recordAlarmHack { sh vbl } {
    global JNXalarms
    global lastPoll

    set lastPoll($sh) [clock seconds]

    # Here we assume a fixed order
    set vb [lindex $vbl 0]
    set redAlarms [lindex $vb 2]

    set vb [lindex $vbl 1]
    set yellowAlarms [lindex $vb 2]

    foreach c {yellow red} {
	if { ! [info exists JNXalarms($r,$c)] } {
	    set JNXalarms($r,$c) 0
	}
    }
    if { $yellowAlarms != $JNXalarms($r,yellow) } {
	JNXalarm $r yellow $JNXalarms($r,yellow) $yellowAlarms
	set JNXalarms($r,yellow) $yellowAlarms
    }
    if { $redAlarms != $JNXalarms($r,red) } {
	JNXalarm $r "red" $JNXalarms($r,red) $redAlarms
	set JNXalarms($r,red) $redAlarms
    }
}


proc checkAlarmHack { sh } {
    
    # jnxUtilUintValue."RedAlarm"
    set qvl "jnxUtilUintValue.82.101.100.65.108.97.114.109"
    # jnxUtilUintValue."YellowAlarm"
    set qvl "$qvl jnxUtilUintValue.89.101.108.108.111.119.65.108.97.114.109"

    $sh get $qvl {
	if { "%E" != "noError" } {
	    return
	}
	recordAlarmHack %S "%V"
    }
}


proc checkJNXalarm { sh } {
    global isJuniper
    
    set r [name $sh]
    if [info exists isJuniper($r)] {
	if { ! $isJuniper($r) } {
	    return
	}
    } else {
	log [format "%s isJuniper could not be determined" $r]
	return
    }

    set qvl "jnxYellowAlarmCount.0 jnxRedAlarmCount.0"

#    log [format "debug: %s checking juniper alarms" $r]
    $sh get $qvl {
	if { "%E" != "noError" } {
	    if { "%E" == "noSuchObject" } {
		checkAlarmHack %S
	    }
	    return
	}
	recordJNXalarms %S "%V"
    }
}
