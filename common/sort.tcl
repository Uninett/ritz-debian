#
# $Id$
#

#
# Procedures for sorting cases and to get severity for a case.
#

catch { namespace delete ::sort }

namespace eval ::sort {
    namespace export sortCases caseSeverity
    namespace export Sortby

    variable Sortby
    if { ! [info exists Sortby] } {
	set Sortby "default"
    }


    # compare administratively set states

    proc compareStates { a b } {

	set a [attr::get $a "state"]
	set b [attr::get $b "state"]

	if { $a == $b } { return 0; }

	foreach s "open working waiting confirm-wait closed" {
	    if { $a == $s } { return -1; }
	    if { $b == $s } { return 1; }
	}
	puts [format "resorting to string compare for %s <-> %s" $a $b]
	return [string compare $a $b];# last resort
    }

    # Compare port states as given above.

    proc comparePortStates { a b } {

	set a [attr::effectivePortState $a]
	set b [attr::effectivePortState $b]

	if { $a == $b } { return 0; }
	foreach s "up adminDown flapping down" {
	    if { $a == $s } { return 1; }
	    if { $b == $s } { return -1; }
	}
	puts [format "resorting to string compare for %s <-> %s" $a $b]
	return [string compare $a $b];# last resort
    }

    # Compare different case types ("portstate" before "reachability")

    proc compareTypes { a b } {

	set a [attr::get $a "type"]
	set b [attr::get $b "type"]
	
	if { $a == $b } { return 0; }
	if { $a == "portstate" } { return -1; }
	if { $b == "portstate" } { return 1; }
	puts [format "resorting to string compare for %s <-> %s" $a $b]
	return [string compare $a $b]; # last resort
    }

    proc compareReachability { a b } {

	set a [attr::get $a "reachability"]
	set b [attr::get $b "reachability"]

	if { $a == $b } { return 0; }
	if { $a == "noResponse" } { return -1; }
	puts [format "resorting to string compare for %s <-> %s" $a $b]
	return [string compare $a $b]; # last resort
    }

    proc numCompare { a b } {

	if { $a == $b } { return 0; }
	if { $a < $b } { return -1; }
	return 1
    }

    proc comparePriority { a b } {

	set a [attr::priority $a]
	set b [attr::riority $b]
	numCompare $b $a
    }

    proc compareUpdated { a b } {

	if [catch { set a [attr::get $a "updated"] }] { return 0; }
	if [catch { set b [attr::get $b "updated"] }] { return 1; }

	numCompare $a $b
    }

    proc compareUpdatedRev { a b } {

	return [compareUpdated $b $a]
    }

    proc compareAge { a b } {

	set a [attr::age $a]
	set b [attr::age $b]
	numCompare $b $a
    }

    proc compareAgeRev { a b } {

	return [compareAge $b $a]
    }

    proc compareSeverity { a b } {

	set a [caseSeverity $a]
	set b [caseSeverity $b]

	if { $a == $b } { return 0; }
	foreach s {alarm warning normal unknown closed} {
	    if { $a == $s } { return -1; }
	    if { $b == $s } { return 1; }
	}
	puts [format "resorting to string compare for %s <-> %s" $a $b]
	return [string compare $a $b]; # last resort
    }

    proc compareDowntime { a b } {

	set ad 0
	set bd 0

	catch { set ad [attr::downtime $a] }
	catch { set bd [attr::downtime $b] }

	numCompare $bd $ad
    }

    proc compareDowntimeRev { a b } {

	return [compareDowntime $b $a]
    }

    # Return severity of a given case.
    # One of alarm, warning, normal, unknown.

    proc caseSeverity { id } {

	set type [Attr $id "type"]
	set state [Attr $id "state"]
	if { $state == "closed" } { return "closed"; }
	if { $type == "portstate" } {
	    set pstate [getEffectivePortState $id]
	    if { $pstate == "down" || $pstate == "flapping" } {
		if { $state == "open" } {
		    return "alarm"
		} else {
		    return "warning"
		}
	    } elseif { $pstate == "up" } {
		return "normal"
	    } elseif { $pstate == "adminDown" } {
		if { $state == "open" } {
		    return "unknown"
		} else {
		    return "warning"
		}
	    } else {
		return "unknown"
	    }
	} elseif { $type == "reachability" } {
	    set reach [Attr $id "reachability"]
	    if { $reach == "no-response" } {
		return "alarm"
	    } else {
		return "normal"
	    }
	} else {
	    return "unknown"
	}
    }

    proc compareCases { a b } {

	set s [compareSeverity $a $b]
	#    puts [format "severity: %s" $s]
	if { $s != 0 } {return $s; }

	set s [compareTypes $a $b]
	#    puts [format "types: %s" $s]
	if { $s != 0 } { return $s; }

	if { [Attr $a "type"] == "portstate" } {
	    set s [comparePortStates $a $b]
	    #	puts [format "portstate: %s" $s]
	    if { $s != 0 } { return $s; }
	} elseif { [Attr $a "type"] == "reachability" } {
	    set s [compareReachability $a $b]
	    #	puts [format "reach: %s" $s]
	    if { $s != 0 } { return $s; }
	}
	set s [comparePriority $a $b]
	#    puts [format "priority: %s" $s]
	if { $s != 0 } { return $s; }

	set s [compareDowntime $a $b]
	if { $s != 0 } { return $s; }

	set s [compareStates $a $b]
	#    puts [format "states: %s" $s]
	if { $s != 0 } { return $s; }

	set s [compareAge $a $b]
	#    puts [format "age: %s" $s]
	return $s
    }

    proc sortCases { caseids } {
	variable Sortby

	if { $Sortby == "default" } {
	    return [lsort -command compareCases $caseids]
	}
	if { $Sortby == "age" } {
	    return [lsort -command compareAge $caseids]
	}
	if { $Sortby == "age-rev" } {
	    return [lsort -command compareAgeRev $caseids]
	}
	if { $Sortby == "updated" } {
	    return [lsort -command compareUpdated $caseids]
	}
	if { $Sortby == "upd-rev" } {
	    return [lsort -command compareUpdatedRev $caseids]
	}
	if { $Sortby == "down" } {
	    return [lsort -command compareDowntime $caseids]
	}
	if { $Sortby == "down-rev" } {
	    return [lsort -command compareDowntimeRev $caseids]
	}
	error [format "Unknown sort option: %s" $Sortby]
    }
}