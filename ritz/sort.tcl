#
# $Id$
#

#
# Routines prioritizing cases
#


# compare administratively set states

proc compareStates { a b } {

    set as "open"
    set bs "open"

    if [catch { set as [Attr $a "state"] }] {
	puts "No state attr for $a"
    }
    if [catch { set bs [Attr $b "state"] }] {
	puts "No state attr for $b"
    }

    if { $as == $bs } { return 0; }

    foreach s "open working waiting confirm-wait ignored closed" {
	if { $as == $s } { return -1; }
	if { $bs == $s } { return 1; }
    }
    puts [format "resorting to string compare for %s <-> %s" $as $bs]
    return [string compare $as $bs];# last resort
}

# Compare port states as given above.

proc comparePortStates { a b } {

    set as "down"
    set bs "down"

    if [catch { set as [getEffectivePortState $a] }] {
	puts "No portstate for $a"
    }
    if [catch { set bs [getEffectivePortState $b] }] {
	puts "No portstate for $b"
    }

    if { $as == $bs } { return 0; }
    foreach s "up adminDown flapping down" {
	if { $as == $s } { return 1; }
	if { $bs == $s } { return -1; }
    }
    puts [format "resorting to string compare for %s <-> %s" $as $bs]
    return [string compare $as $bs];# last resort
}

# Compare different case types ("portstate" before "reachability")

proc compareTypes { a b } {

    if { ! [AttrExists $a "type"] } {
	puts "No type attr for $a"
	return 1;
    }
    if { ! [AttrExists $b "type"] } {
	puts "No state for $b"
	return -1;
    }

    set a [Attr $a "type"]
    set b [Attr $b "type"]
    
    if { $a == $b } { return 0; }
    if { $a == "portstate" } { return -1; }
    if { $b == "portstate" } { return 1; }

    puts [format "resorting to string compare for %s <-> %s" $a $b]
    return [string compare $a $b]; # last resort
}

proc compareReachability { a b } {

    set ar "noResponse"
    set br "noResponse"

    if [catch { set ar [Attr $a "reachability"] }] {
	puts "No reachability attr for $a" 
    }
    if [catch { set br [Attr $b "reachability"] }] {
	puts "No reachability attr for $b"
    }

    if { $ar == $br } { return 0; }
    if { $ar == "noResponse" } { return -1; }
    puts [format "resorting to string compare for %s <-> %s" $ar $br]
    return [string compare $ar $br]; # last resort
}

proc numCompare { a b } {

    if { $a == $b } { return 0; }
    if { $a < $b } { return -1; }
    return 1
}

proc comparePriority { a b } {

    set an 100
    set bn 100

    if [catch { set an [getPriority $a] }] {
	puts "No priority for $a"
    }
    if [catch { set bn [getPriority $b] }] {
	puts "No priority for $b"
    }

    numCompare $bn $an
}

proc compareUpdated { a b } {

    if [catch { set a [Attr $a "updated"] }] {
	puts "No updated attr for $a"
	return 0;
    }
    if [catch { set b [Attr $b "updated"] }] {
	puts "No updated attr for $b"
	return 1;
    }

    numCompare $a $b
}

proc compareUpdatedRev { a b } {

    return [compareUpdated $b $a]
}

proc compareAge { a b } {

    set aa 0
    set ba 0

    if [catch { set aa [getAge $a] }] {
	puts "No age for $a"
    }
    if [catch { set ba [getAge $b] }] {
	puts "No age for $b"
    }

    numCompare $ba $aa
}

proc compareAgeRev { a b } {

    return [compareAge $b $a]
}

proc compareSeverity { a b } {

    set as "unknown"
    set bs "unknown"
    
    if [catch { set as [caseSeverity $a] }] {
	puts "No severity for $a"
    }
    if [catch { set bs [caseSeverity $b] }] {
	puts "No severity for $b"
    }

    if { $as == $bs } { return 0; }
    foreach s {alarm warning normal unknown closed} {
	if { $as == $s } { return -1; }
	if { $bs == $s } { return 1; }
    }
    puts [format "resorting to string compare for %s <-> %s" $as $bs]
    return [string compare $as $bs]; # last resort
}

proc compareDowntime { a b } {

    set ad 0
    set bd 0

    if [catch { set ad [getDowntime $a] }] {
	puts "No downtime for $a"
    }
    if [catch { set bd [getDowntime $b] }] {
	puts "No downtime for $b"
    }

    numCompare $bd $ad
}

proc compareDowntimeRev { a b } {

    return [compareDowntime $b $a]
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

    if { [AttrExists $a "type"] } {
	if { [Attr $a "type"] == "portstate" } {
	    set s [comparePortStates $a $b]
#	puts [format "portstate: %s" $s]
	    if { $s != 0 } { return $s; }
	} elseif { [Attr $a "type"] == "reachability" } {
	    set s [compareReachability $a $b]
#	puts [format "reach: %s" $s]
	    if { $s != 0 } { return $s; }
	}
    }

    set s [comparePriority $a $b]
#    puts [format "priority: %s" $s]
    if { $s != 0 } { return $s; }

    set s [compareStates $a $b]
#    puts [format "states: %s" $s]
    if { $s != 0 } { return $s; }

    set s [compareDowntime $a $b]
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
    if { $Sortby == "down" } {
	return [lsort -command compareDowntime $caseids]
    }
    if { $Sortby == "down-rev" } {
	return [lsort -command compareDowntimeRev $caseids]
    }
    error [format "Unknown sort option: %s" $Sortby]
}

# Return severity of a given case.
# One of alarm, warning, normal, unknown.

proc caseSeverity { id } {

    if { ! [AttrExists $id "type"] } {
	puts "No type attr for $id"
	return "unknown";
    }
    if { ! [AttrExists $id "state"] } {
	puts "No state attr for $id"
	return "unknown";
    }

    set type [Attr $id "type"]
    set state [Attr $id "state"]
    if { $state == "closed" } { return "closed"; }
    if { $state == "ignored" } { return "normal"; }
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
	    if { $state == "open" } {
		return "alarm"
	    } else {
		return "warning"
	    }
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

	    if { $attr == "downtime" } {
		set val [getDowntime $id]
	    } elseif { [catch { set val [Attr $id $attr] } msg] } {
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
		    "value>=" {
			set match [expr $val >= $FilterVal($attr)]
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
