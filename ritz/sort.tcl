#
# $Id$
#

#
# Routines prioritizing cases
#


# compare administratively set states

proc compareStates { a b } {

    set a [Attr $a "state"]
    set b [Attr $b "state"]

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

    set a [getEffectivePortState $a]
    set b [getEffectivePortState $b]

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

    set a [Attr $a "type"]
    set b [Attr $b "type"]
    
    if { $a == $b } { return 0; }
    if { $a == "portstate" } { return -1; }
    if { $b == "portstate" } { return 1; }
    puts [format "resorting to string compare for %s <-> %s" $a $b]
    return [string compare $a $b]; # last resort
}

proc compareReachability { a b } {

    set a [Attr $a "reachability"]
    set b [Attr $b "reachability"]

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

    set a [getPriority $a]
    set b [getPriority $b]
    numCompare $b $a
}

proc compareUpdated { a b } {

    if [catch { set a [Attr $a "updated"] }] { return 0; }
    if [catch { set b [Attr $b "updated"] }] { return 1; }

    numCompare $a $b
}

proc compareUpdatedRev { a b } {

    return [compareUpdated $b $a]
}

proc compareAge { a b } {

    set a [getAge $a]
    set b [getAge $b]
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

#
# Main sorting routine
#

proc compareCases { a b } {

    set s [compareSeverity $a $b]
#    puts [format "severity: %s" $s]
    if { $s != 0 } {return $s; }

    set s [compareTypes $a $b]
#    puts [format "types: %s" $s]
    if { $s != 0 } { return $s; }

    set s [compareStates $a $b]
#    puts [format "states: %s" $s]
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

    set s [compareAge $a $b]
#    puts [format "age: %s" $s]
    return $s
}

if { ! [info exists Sortby] } {
    set Sortby "default"
}

proc sortCases { caseids } {
    global Sortby

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
    error [format "Unknown sort option: %s" $Sortby]
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

# Is the filter empty?

proc filterIsEmpty { } {
    global FilterOn

    foreach attr [array names FilterOn] {
	if { $FilterOn($attr) } {
	    return 0
	}
    }
    return 1
}

# Does a given case pass the current filter settings?

proc filterPass { id } {
    global FilterOn
    global FilterHow
    global FilterVal
    global Selected

    set allmatch 1;		# initial assumption
    foreach attr [array names FilterOn] {
	if { ! $FilterOn($attr) } { continue; }
	if { $attr == "selected" } {
	    set match [info exists Selected($id)]
	} else {

	    if { [catch { set val [Attr $id $attr] } msg] } {
#		puts [format "Attr %s does not exist for id %s" $attr $id]
		return 0;		# attribute does not exist, so no match
	    }
	    if { [info exists FilterHow($attr)] } {
		switch -exact $FilterHow($attr) {
		    exact {
			set match [expr {$val} == {$FilterVal($attr)}]
		    }
		    glob {
			set match [string match $FilterVal($attr) $val]
		    }
		    regexp {
			set match [regexp -- $Filterval($attr) $val]
		    }
		}
	    } else {
		set match [expr {$FilterVal($attr)} == {$val}]
	    }
	}
	set allmatch [expr $allmatch && $match]
	if { ! $allmatch } {
	    return 0;		# Cannot possibly match now
	}
    }
    return $allmatch;		# Should always be 1
}

# Filter the given cases with the current filter, return
# list of case IDs which passed through the filter.

proc filterCases { caseIds } {

    set newids {}
    foreach id $caseIds {
	if { [filterPass $id] } {
	    lappend newids $id
	}
    }
    return $newids
}
