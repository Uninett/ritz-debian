#
# $Id$
#

catch { namespace delete ::attr }

namespace eval ::attr {
    namespace export exists get set names
    namespace export forget forgetAll
    namespace export effectivePortState priority age downtime
    namespace export isDown isUpState isDownState getOperState

    variable defaultPriority


    proc exists { id attr } {
	::set av Attrs_$id
	global $av

	return [info exists [::set av]($attr)]
    }

    proc get { id attr } {
	::set av Attrs_$id
	global $av
	
	return [::set [::set av]($attr)]
    }

    proc set { id attr value } {
	::set av Attrs_$id
	global $av

	::set [::set av]($attr) $value
    }

    proc names { id } {
	::set av Attrs_$id
	global $av
	
	return [array names $av]
    }

    proc forget { id } {
	::set av Attrs_$id
	global $av
	
	unset $av
    }

    proc forgetAll {} {

	foreach gv [info globals "^Attrs_.*"] {
	    global $gv
	    unset $gv
	}
    }

    proc effectivePortState { id } {

	::set state [get $id "portstate"]

	if { $state == "up" } {
	    if { [exists $id "flapstate"] } {
		::set flapstate [get $id "flapstate"]
		if { $flapstate != "stable" } {
		    return $flapstate
		}
	    }
	}
	return $state
    }

    proc priority { id } {
	variable defaultPriority

	if { [exists $id "priority"] } {
	    return [get $id "priority"]
	}
	return $defaultPriority
    }

    proc age { id } {

	return [expr [clock seconds] - [get $id "opened"]]
    }

    proc getOperState { id } {
	
	::set type [get $id "type"]
	if { $type == "portstate" } {
	    return [effectivePortState $id]
	} elseif { $type == "reachability" } {
	    return [get $id "reachability"]
	} else {
	    return "unknown"
	}
    }

    proc isDownState { state } {

	if {    $state == "down" || \
		$state == "flapping" || \
		$state == "no-response" } {
	    return 1
	}
	return 0
    }

    proc isUpState { state } {

	return [expr ! [isDownState $state]]
    }

    proc isDown { id } {

	::set os [getOperState $id]
	return [isDownState $os]
    }

    proc downtime { id } {

	::set now [clock seconds]
	::set lt $now
	catch { ::set lt [get $id "lasttrans"] }
	if { $lt == 0 } {
	    ::set lt $now
	}
	::set ad 0
	catch { ::set ad [get $id "ac-down"] }
	if [isDown $id] {
	    ::set ad [expr $ad + $now - $lt]
	}
	return $ad
    }

}
