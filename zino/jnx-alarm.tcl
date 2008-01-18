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

    foreach c {"yellow" "red"} {
	if { ! [info exists JNXalarms($r,$c)] } {
	    set JNXalarms($r,$c) 0
	}
    }
    if { $jnxYellowAlarmCount != $JNXalarms($r,"yellow") } {
	JNXalarm $r "yellow" $JNXalarms($r,"yellow") $jnxYellowAlarmCount
	set JNXalarms($r,"yellow") $jnxYellowAlarmCount
    }
    if { $jnxRedAlarmCount != $JNXalarms($r,"red") } {
	JNXalarm $r "red" $JNXalarms($r,"red") $jnxRedAlarmCount
	set JNXalarms($r,"red") $jnxRedAlarmCount
    }
}

proc checkJNXalarm { sh } {
    global isJuniper

    if { ! $isJuniper($sh) } {
	return
    }

    set qvl "jnxYellowAlarmCount.0 jnxRedAlarmCount.0"

    $sh get $qvl {
	if { "%E" != "noError" } {
	    return
	}
	recordJNXalarms %S "%V"
    }
}
