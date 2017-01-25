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

    # Port state ranks first
    if { $a == "portstate" } { return -1; }
    if { $b == "portstate" } { return 1; }

    # Alarm state ranks above BGP
    if { $a == "alarm" } { return -1; }
    if { $b == "alarm" } { return 1; }

    # BFD state ranks above BGP
    if { $a == "bfd" } { return -1; }
    if { $b == "bfd" } { return 1; }

    # BGP state ranks above reachability
    if { $a == "bgp" } { return -1; }
    if { $b == "bgp" } { return 1; }

    puts [format "resorting to string compare for %s <-> %s" $a $b]
    return [string compare $a $b]; # last resort
}

proc compareReachability { a b } {

    set ar "noResponse"
    set br "noResponse"

    if [catch { set ar [Attr $a "reachability"] }] {
	puts "No reachability attr for $a" 
	return 1
    }
    if [catch { set br [Attr $b "reachability"] }] {
	puts "No reachability attr for $b"
	return -1
    }

    if { $ar == $br } { return 0; }
    if { $ar == "noResponse" } { return -1; }
    puts [format "resorting to string compare for %s <-> %s" $ar $br]
    return [string compare $ar $br]; # last resort
}

proc compareBgp { a b } {

    if [catch { set ao [Attr $a "bgpOS"] }] {
	puts "no bgpOS for $a"
	return 1
    }
    if [catch { set bo [Attr $b "bgpOS"] }] {
	puts "no bgpOS for $b"
	return -1
    }

    if { $ao != $bo } {
	if { $ao == "established" } { return 1; }
	if { $bo == "established" } { return -1; }
    }

    if [catch { set aa [Attr $a "bgpAS"] }] {
	puts "no bgpAS for $a"
	return 1
    }
    if [catch { set ba [Attr $a "bgpAS"] }] {
	puts "no bgpAS for $b"
	return -1
    }

    if { $aa != $ba } {
	if { $aa != "start" } { return 1; }
	if { $ba != "start" } { return -1; }
    }
    return 0;
}

proc compareBFD { a b } {

    if [catch { set as [Attr $a "bfdState"] }] {
	puts "no bfd-state for $a"
	return 1
    }
    if [catch { set bs [Attr $b "bfdState"] }] {
	puts "no bfd-state for $b"
	return -1
    }
    if { $as != $bs } {
	if { $as == "down" } { return -1; }
	if { $bs == "down" } { return 1; }
	if { $as == "up" } { return 1; }
	if { $bs == "up" } { return -1; }
    }
    return 0
}

proc compareAlarms { a b } {

    if [catch { set at [Attr $a "alarm-type"] }] {
	puts "no alarm-type for $a"
	return 1
    }
    if [catch { set bt [Attr $a "alarm-type"] }] {
	puts "no alarm-type for $b"
	return -1
    }
    
    if { $at != $bt } {
	if { $at == "red" } { return -1; }
	if { $bt == "red" } { return 1; }
    }

    if [catch { set ac [Attr $a "alarm-count"] }] {
	puts "no alarm-count for $a"
	return 1
    }
    if [catch { set bc [Attr $a "alarm-count"] }] {
	puts "no alarm-count for $b"
	return -1
    }

    if { $ac != $bc } {
	return $ac <=> $bc;
    }
    return 0;
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

    catch { set aa [getAge $a] }
    catch { set ba [getAge $b] }

    numCompare $aa $ba
}

proc compareAgeRev { a b } {

    return [compareAge $b $a]
}

proc compareSeverity { a b } {

    set as "unknown"
    set bs "unknown"
    
    catch { set as [caseSeverity $a] }
    catch { set bs [caseSeverity $b] }

    if { $as == $bs } { return 0; }
    foreach s {alarm alert warning normal unknown closed} {
	if { $as == $s } { return -1; }
	if { $bs == $s } { return 1; }
    }
    puts [format "resorting to string compare for %s <-> %s" $as $bs]
    return [string compare $as $bs]; # last resort
}

proc compareDowntime { a b } {

    set ad 0
    set bd 0

    catch { set ad [getDowntime $a] }
    catch { set bd [getDowntime $b] }

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

	set at [Attr $a "type"]

	if { $at == "portstate" } {
	    set s [comparePortStates $a $b]
#	puts [format "portstate: %s" $s]
	    if { $s != 0 } { return $s; }
	} elseif { $at == "reachability" } {
	    set s [compareReachability $a $b]
#	puts [format "reach: %s" $s]
	    if { $s != 0 } { return $s; }
	} elseif { $at == "bgp" } {
	    set s [compareBgp $a $b]
	    if { $s != 0 } { return $s; }
	} elseif { $at == "alarm" } {
	    set s [compareAlarms $a $b]
	    if { $s != 0 } { return $s; }
	} elseif { $at == "bfd" } {
	    set s [compareBFD $a $b]
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
# One of alarm, alert, warning, normal, unknown, or ignored.

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
    if { $state == "ignored" } { return "ignored"; }
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
    } elseif { $type == "alarm" } {
	set colour [Attr $id "alarm-type"]
	set count [Attr $id "alarm-count"]
	if { $count == 0 } {
	    return "normal"
	}
	if { $colour == "yellow" } {
	    if { $state == "open" } {
		return "alert"
	    } else {
		return "warning"
	    }
	}
	if { $state == "open" } {
	    return "alarm"
	} else {
	    return "warning"
	}
    } elseif { $type == "bgp" } {
	set as [Attr $id "bgpAS"]
	if { $as == "start" || $as == "running" } {
	    set os [Attr $id "bgpOS"]
	    if { $os == "established" } {
		return "normal"
	    } else {
		if { $state == "open" } {
		    return "alarm"
		} else {
		    return "warning"
		}
	    }
	} else {
	    return "unknown"
	}
    } elseif { $type == "bfd" } {
	set s [Attr $id "bfdState"]
	if { $s == "up" } {
	    return "normal"
	} elseif { $s == "down" } {
	    if { $state == "open" } {
		return "alarm"
	    } else {
		return "warning"
	    }
	} else {
	    return "warning"
	}
    } else {
	return "unknown"
    }
    puts [format "Id %d: fell off end of caseSeverity" $id]
    return "unknown"
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
	    } elseif { $attr == "bgpstate" } {
		# Needs to be open-coded, synthesized states
		set tp  [Attr $id "type"]
		if { $tp != "bgp" } {
		    return 0;	# not bgp, so no match
		}
		set as [Attr $id "bgpAS"]
		set os [Attr $id "bgpOS"]
		if { $FilterVal($attr) == "established" } {
		    if { $os == "established" } {
			return 1;
		    } else {
			return 0;
		    }
		} elseif { $FilterVal($attr) == "down" } {
		    if { $as == "start" || $as == "running" } {
			if { $os != "established" } {
			    return 1;
			} else {
			    return 0;
			}
		    }
		} elseif { $FilterVal($attr) == "admin-down" } {
		    if { $as == "stop" || $as == "halted" } {
			return 1;
		    } else {
			return 0;
		    }
		}
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
			set match [regexp -- $FilterVal($attr) $val]
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
