# 
# $Id$
#

# Routines to do "sparse table walk", using SNMPv1 GET-NEXT.


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
	    if { $li == 0 || [string compare $inst $li] == -1} {
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

proc processRow { sh vbl err slist var action args } {
    global swalkErrorHandler

    set call_next [lindex $args 0]
    set call_error [lindex $args 1]

    if { $err == "noError" } {
	set li [getLowestMatch $slist $vbl]
	set vbl [filterLowestMatching $slist $li $vbl]
	if { [string compare "" $vbl] == 0 } {
	    if { $call_next != "" } {
		eval $call_next $sh
	    }
	    return;		# no matches, end of table
	}
	set $var $vbl
	eval $action
	foreach elt $slist {
	    lappend nslist [format "%s.%s" $elt $li]
	}
	$sh getnext $nslist \
	    [concat processRow "%S" {"%V"} "%E" \
		 [list $slist] $var [list $action] $args]
    } else {
	if { $call_error != "" } {
	    eval $call_error $sh $err
	} elseif { [info exists swalkErrorHandler] } {
	    $swalkErrorHandler $sh $err
	} else {
	    error $err
	}
    }
}

# Do a walk of a sparse table.  May unwind with error-return.

proc sparseWalk { sh startList x action args } {
    foreach v $startList {
	lappend oidsl [mib oid $v]
    }
    $sh getnext $oidsl \
	    [concat processRow "%S" {"%V"} "%E" \
		 [list $oidsl] $x [list $action] [list $args]]
    return
}

proc setSWalkEhandler { p } {
    global swalkErrorHandler
    
    set swalkErrorHandler $p
}
