#
# $Id$
#

#
# Procedures producing the textual one-line summary of a case and
# the heading to go with it.  Try to make all lines of equal length.
#

proc summaryLen { } {
    global View
    
    set l 0
    if { $View(id) } {
	set l [expr $l + 5]
    }
    if { $View(opstate) } {
	set l [expr $l + 16]
    }
    if { $View(admstate) } {
	set l [expr $l + 9]
    }
    if { $View(priority) } {
	set l [expr $l + 5]
    }
    if { $View(updated) } {
	set l [expr $l + 17]
    }
    if { $View(downtime) } {
	set l [expr $l + 17]
    }
    if { $View(age) } {
	set l [expr $l + 17]
    }
    if { $View(router) } {
	set l [expr $l + 17]
    }
    if { $View(port) } {
	set l [expr $l + 20]
    }
    if { $View(descr) } {
	set l [expr $l + 80]
    }
    return $l
}

proc summarizePort { id } {
    global View

    set s ""
    if { $View(id) } {
	set s [format "%5s" $id]
    }
    if { $View(opstate) && $View(admstate) } {
	set ps [format "port %s" [getEffectivePortState $id]]
	set l [string length $ps]
	set ll [expr 5 + 10 + 8 - $l]
	set s [format "%s %s %*s" $s $ps $ll [Attr $id "state"]]
    } else {
	if { $View(opstate) } {
	    set s [format "%s port %-10s" $s [getEffectivePortState $id]]
	}
	if { $View(admstate) } {
	    set s [format "%s %8s" $s [Attr $id "state"]]
	}
    }
    if { $View(priority) } {
	set s [format "%s %4s" $s [getPriority $id]]
    }
    if { $View(age) } {
	set s [format "%s %16s" $s [mib format sysUpTime \
		[expr [getAge $id] * 100]]]
    }
    if { $View(downtime) } {
	set downtime 0
	catch { set downtime [getDowntime $id] }
	set s [format "%s %16s" $s [mib format sysUpTime \
		[expr $downtime * 100]]]
    }
    if { $View(updated) } {
	set secs [expr [clock seconds] - [Attr $id "updated"]]
	set s [format "%s %16s" $s [mib format sysUpTime \
		[expr $secs * 100]]]
    }
    if { $View(router) } {
	set s [format "%s %-16s" $s [Attr $id "router"]]
    }
    if { $View(port) } {
	set s [format "%s %-20s" $s [Attr $id "port"]]
    }
    if { [AttrExists $id "descr"] && $View(descr) } {
	set s [format "%s (%s)" $s [Attr $id "descr"]]
    }
    return [format "%-*s" [summaryLen] $s]
}

proc summarizeBGP { id } {
    global View

    set s ""
    if { $View(id) } {
	set s [format "%5s" $id]
    }
    if { $View(opstate) && $View(admstate) } {
	set os [format "bgp %s" [Attr $id "bgpOS"]]
	set l [string length $os]
	set rl [expr 5 + 10 + 8 - $l]
	set s [format "%s %s %*s" $s $os $rl [Attr $id "bgpAS"]]
    } else {
	if { $View(opstate) } {
	    set s [format "%s bgp %-10s" $s [Attr $id "bgpOS"]]
	}
	if { $View(admstate) } {
	    set s [format "%s %8s" $s [Attr $id "bgpAS"]]
	}
    }
    if { $View(priority) } {
	set s [format "%s %4s" $s [getPriority $id]]
    }
    if { $View(age) } {
	set s [format "%s %16s" $s [mib format sysUpTime \
	    [expr [getAge $id] * 100]]]
    }
    if { $View(downtime) } {
	set s [format "%s %16s" $s ""]
    }
    if { $View(updated) } {
	set secs [expr [clock seconds] - [Attr $id "updated"]]
	set s [format "%s %16s" $s [mib format sysUpTime \
		[expr $secs * 100]]]
    }
    if { $View(router) } {
	set s [format "%s %-16s" $s [Attr $id "router"]]
    }
    if { $View(port) } {
	set s [format "%s %-20s" $s \
		   [format "AS %s %s" \
			[Attr $id "remote-AS"] \
			[Attr $id "remote-addr"] \
		       ]]
    }
    if { [AttrExists $id "lastevent"] && $View(descr) } {
	set s [format "%s (%s)" $s [Attr $id "lastevent"]]
    }
    return [format "%-*s" [summaryLen] $s]
}

proc summarizeReach { id } {
    global View

    set s ""
    if { $View(id) } {
	set s [format "%5s" $id]
    }
    if { $View(opstate) } {
	set s [format "%s %-15s" $s [Attr $id "reachability"]]
    }
    if { $View(admstate) } {
	set s [format "%s %8s" $s [Attr $id "state"]]
    }
    if { $View(priority) } {
	set s [format "%s %4s" $s [getPriority $id]]
    }
    if { $View(age) } {
	set s [format "%s %16s" $s [mib format sysUpTime \
	    [expr [getAge $id] * 100]]]
    }
    if { $View(downtime) } {
	set downtime [getDowntime $id]
	set s [format "%s %16s" $s [mib format sysUpTime \
		[expr $downtime * 100]]]
    }
    if { $View(updated) } {
	set secs [expr [clock seconds] - [Attr $id "updated"]]
	set s [format "%s %16s" $s [mib format sysUpTime \
		[expr $secs * 100]]]
    }
    if { $View(router) } {
	set s [format "%s %-16s" $s [Attr $id "router"]]
    }
    return [format "%-*s" [summaryLen] $s]
}

proc summaryStr { id } {

    set type [Attr $id "type"]
    if { $type == "portstate" } {
	return [summarizePort $id]
    } elseif { $type == "reachability" } {
	return [summarizeReach $id]
    } elseif { $type == "bgp" } {
	return [summarizeBGP $id]
    } else {
	puts stderr [format "Ignoring unknown case type: %s, id %s" $type $id]
    }
}

proc summaryHeading { } {
    global View

    set h ""
    if { $View(id) } {
	set h [format "%5s" "Id"]
    }
    if { $View(opstate) } {
	set h [format "%s %-15s" $h "OpState"]
    }
    if { $View(admstate) } {
	set h [format "%s %8s" $h "AdmState"]
    }
    if { $View(priority) } {
	set h [format "%s %4s" $h "Pri"]
    }
    if { $View(age) } {
	set h [format "%s %-16s" $h " Age"]
    }
    if { $View(downtime) } {
	set h [format "%s %-16s" $h " Downtime"]
    }
    if { $View(updated) } {
	set h [format "%s %-16s" $h " Updated"]
    }
    if { $View(router) } {
	set h [format "%s %-16s" $h "Router"]
    }
    if { $View(port) } {
	set h [format "%s %-20s" $h "Port"]
    }
    if { $View(descr) } {
	set h [format "%s %s" $h "Description"]
    }
    return [format "%-*s" [summaryLen] $h]
}
