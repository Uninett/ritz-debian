#
# $Id$
#
# Read config file, stash values in global tables
#

proc readCf { filename } {
    global Interval Address Dns IgnorePat Priority Timeout Retry
    global DefaultCommunity DefaultDomain DefaultInterval
    global DefaultPriority DefaultTimeout DefaultRetry
    global DeletedRouter
    global NewRouter
    global ChangedRouter
    global cx

    set f [open $filename]
    set globals 1

    while {[gets $f line] >= 0} {
	if { [regexp "^$" $line] } {
	    set globals 0
	    set router 0
	    continue
	}
	# comments, start in col 0
	if { [regexp "^#" $line] } { continue; }
	set l [split $line]
	if { $globals } {
	    set val [lindex $l 1]
	    switch [lindex $l 0] {
		community: {
		    set DefaultCommunity $val
		}
		domain: {
		    set DefaultDomain $val
		}
		interval: {
		    set DefaultInterval $val
		}
		defaultpriority: {
		    set DefaultPriority $val
		}
		timeout: {
		    set DefaultTimeout $val
		}
		retry: {
		    set DefaultRetry $val
		}
		default {
		    puts [format "unknown global directive: %s" $line]
		}
	    }
	} else {
	    set val [lindex $l 1]
	    if { $router } {
		switch [lindex $l 0] {
		    address: {
			set vars {Address}
		    }
		    community: {
			set vars {cf_Community}
		    }
		    dns: {
			set vars {Dns}
		    }
		    interval: {
			set vars {Interval cf_Interval}
		    }
		    ignorepat: {
			set vars {cf_IgnorePat}
		    }
		    priority: {
			set vars {cf_Priority}
		    }
		    timeout: {
			set vars {cf_Timeout}
		    }
		    retry: {
			set vars {cf_Retry}
		    }
		    default {
			puts [format "unknown router directive: %s" $line]
			set vars {}
		    }
		}
		foreach v $vars {
		    if {[info exists [set v]($name)]} {
			if {[set [set v]($name)] != $val} {
			    puts [format "Router %s changed config" $name]
			    puts [format "Var %s value %s" $v $val]
			    set ChangedRouter($name) 1
			}
		    }
		    set [set v]($name) $val
		}
	    } else {
		if {[lindex $l 0] == "name:"} {
		    set router 1
		    set name $val
		    set seenRouter($name) 1
		    # if Interval($r) was not set in previous read of the
		    # configuration file, we have a new router
		    if {! [info exists Interval($name)]} {
			puts [format "Router %s is new" $name]
			set NewRouter($name) 1
		    }
		}
	    }
	}
    }
    close $f

    # Detect deleted routers
    foreach r [oldRouterNames] {
	if {! [info exists seenRouter($r)]} {
	    puts [format "Router %s is removed" $r]
	    set DeletedRouter($r) 1
	    cleanupDBvars $r
	}
    }

    # Set built-in defaults if they're not already set by the config file

    if {! [info exists DefaultPriority] } {
	set DefaultPriority 100
    }
    if {! [info exists DefaultCommunity] } {
	set DefaultCommunity "public"
    }
    if {! [info exists DefaultInterval] } {
	set DefaultInterval 15
    }
    if {! [info exists DefaultTimeout] } {
	set DefaultTimeout 5
    }
    if {! [info exists DefaultRetry] } {
	set DefaultRetry 3
    }

    # Default community context attribute, interval and priority
    foreach r [array names seenRouter] {

	if {[info exists cf_Community($r)]} {
	    set cx($r,community) $cf_Community($r)
	} else {
	    set cx($r,community) $DefaultCommunity
	}

	if {! [info exists cf_Interval($r)] } {
	    set Interval($r) $DefaultInterval
	}

	if {! [info exists cf_Priority($r)] } {
	    set Priority($r) $DefaultPriority
	} else {
	    set Priority($r) $cf_Priority($r)
	}

	if {! [info exists cf_Timeout($r)] } {
	    set Timeout($r) $DefaultTimeout
	} else {
	    set Timeout($r) $cf_Timeout($r)
	}

	if {! [info exists cf_Retry($r)] } {
	    set Retry($r) $DefaultRetry
	} else {
	    set Retry($r) $cf_Retry($r)
	}

	if {! [info exists cf_IgnorePat($r)] } {
	    catch {unset IgnorePat($r)}
	} else {
	    set IgnorePat($r) $cf_IgnorePat($r)
	}
    }
}

proc checkCfFile { name } {
    global lastMod

    file stat $name st
    if { ! [info exists lastMod] } {
	set lastMod $st(mtime)
	return
    }
    if { $st(mtime) != $lastMod } {
	puts [format "Config file %s updated, rereading" $name]
	if [catch {readCf $name} msg] {
	    return;		# Try again later
	}
	set lastMod $st(mtime)
	puts [format "Config file successfully read"]

	restartPollChangedRouters
	stopPollDeletedRouters
	startPollNewRouters
    }
}

proc startCfCheckJob { name interval } {
    global DefaultInterval

    set msintv [expr $interval * 60 * 1000]
    job create -interval $msintv \
	    -command [list checkCfFile $name]
}

proc cleanupDBvars { r } {
    global AddrToRouter
    global portToIfDescr
    global portToLocIfDescr
    global portState
    global isCisco

    puts [format "Router %s removed, cleaning up" $r]

    set msg [format "Router %s no longer monitored" $r]

    catch { closeEventsOnRouter $r $msg }
    catch { forgetFlaps $r $msg }

    # Clean up in internal "databases"
    foreach a [array names AddrToRouter] {
	if { $AddrToRouter($a) == $r } {
	    unset AddrToRouter($a)
	}
    }
    foreach a "portToIfDescr portToLocIfDescr portState" {
	foreach ix [array names $a] {
	    set l [split $ix ","]
	    if { [lindex $l 0] == $r } {
		unset [set a]($ix)
	    }
	}
    }
    catch { unset isCisco($r) }
}

# Collect names of previously known routers from various sources

proc oldRouterNames { } {
    global AddrToRouter
    global portToIfDescr
    global portToLocIfDescr
    global portState
    global isCisco
    
    foreach a [array names AddrToRouter] {
	set Router($AddrToRouter($a)) 1
    }
    foreach a "portToIfDescr portToLocIfDescr portState" {
	foreach ix [array names $a] {
	    set l [split $ix ","]
	    set Router([lindex $l 0]) 1
	}
    }
    foreach a "isCisco Interval" {
	foreach r [array names $a] {
	    set Router($r) 1
	}
    }

    # Collect values in list
    set l ""
    foreach r [array names Router] {
	lappend l $r
    }
    return $l
}
