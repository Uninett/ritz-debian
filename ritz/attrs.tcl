#
# $Id$
#

#
# Procedures to handle case attributes
#

set DefaultPriority 100

proc AttrExists { id attr } {
    set attrs Attrs_$id
    global $attrs

    return [info exists [set attrs]($attr)]
}

proc Attr { id attr } {
    set attrs Attrs_$id
    global $attrs

    return [set [set attrs]($attr)]
}

proc AttrNames { id } {
    set attrs Attrs_$id
    global $attrs

    return [array names $attrs]
}

proc AttrForget { id } {
    set attrs Attrs_$id
    global $attrs

    unset $attrs
}

# get "portstate" and "flapstate" (if present) and collect
# as one variable.

proc getEffectivePortState { id } {

    set state [Attr $id "portstate"]
    
    if { $state == "up" } {
	if { [AttrExists $id "flapstate"] } {
	    set flapstate [Attr $id "flapstate"]
	    if { $flapstate != "stable" } {
		return $flapstate
	    }
	}
    }
    return $state
}

proc getPriority { id } {
    global DefaultPriority

    if { [AttrExists $id "priority"] } {
	return [Attr $id "priority"]
    }
    return $DefaultPriority
}

proc getAge { id } {

    return [expr [clock seconds] - [Attr $id "opened"]]
}

# Forget all attributes

proc AttrForgetAll {} {

    foreach gv [info globals] {
	if { [regexp "^Attrs_.*" $gv] } {
	    global $gv
	    unset $gv
	}
    }
}

proc isDown { id } {

    set type [Attr $id "type"]
    if { $type == "portstate" } {
	set ps [Attr $id "portstate"]
	if { $ps == "down" || $ps == "flapping" } {
	    return 1
	}
	return 0;
    } elseif { $type == "reachability" } {
	set reach [Attr $id "reachability"]
	if { $reach == "no-response" } {
	    return 1
	}
	return 0
    }
}

# Get current downtime for a given event

proc getDowntime { id } {

    set now [clock seconds]
    set lt $now
    catch { set lt [Attr $id "lasttrans"] }
    if { $lt == 0 } {
	set lt $now
    }
    set ad 0
    catch { set ad [Attr $id "ac-down"] }
    if [isDown $id] {
	set ad [expr $ad + $now - $lt]
    }
    return $ad
}
