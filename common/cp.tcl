#
# $Id$
#

#
# Client Protocol routines.
#

catch { namespace delete ::cp }

namespace eval ::cp {
    namespace export caseIds getAttrs pullCases
    namespace export getLog getCleanLog getHist addHist setState
    namespace export getCommunity pollRouter pollIntf clearFlap

    # community cache
    variable community


    proc caseIds {} {

	set caseids {}
	::net::puts "caseids"
	::net::gets l
	if { ! [regexp {^304} $l] } {
	    error [format "protocol error in caseIds: %s" $l]
	}
	for { ::net::gets l } { $l != "." } { ::net::gets l } {
	    lappend caseids $l
	}
	return $caseids
    }

    proc getAttrs { id } {

	::net::puts "getattrs $id"
	::net::gets l
	if { ! [regexp {^303} $l] } {
	    error [format "protocol error in getAttrs: %s" $l]
	}
	for { ::net::gets l } { $l != "." } { ::net::gets l } {
	    if { ! [regexp {^([^:]+): (.*)$} $l x attr val] } {
		error [format "indiscernible value in getAttrs: %s" $l]
	    }
	    ::attr::set $id $attr $val
	}
    }

    proc pullCases {} {

	set ids [caseIds]
	foreach id $ids {
	    getAttrs $id
	}
	return $ids
    }

    proc cleanLog { log } {
	set newlog ""
	foreach le $log {
	    regexp {^([0-9]+) (.*)$} $l whole stamp rest
	    if { [regexp {changed state from.* on ([0-9]+)} \
		    $rest whole when] } {
		set when_str [clock format $when]
		regsub {(on [0-9]+)} $rest [format "on %s" $when_str] rest
	    }
	    set line [format "%s: %s\n" [clock format $stamp] $rest]
	    set newlog [format "%s%s" $newlog $line]
	}
	return $newlog
    }

    proc getLog { id } {

	::net::puts "getlog $id"
	::net::gets l
	if { ! [regexp {^300} $l] } {
	    error [format "protocol error in getLog: %s" $l
	}
	set log ""
	for { ::net::gets l } { $l != "." } { ::net::gets l } {
	    set log [format "%s%s" $log $l]
	}
	return $log
    }

    proc getCleanLog { id } {

	set log [getLog $id]
	return [cleanLog $log]
    }

    proc getHist { id } {

	::net::puts "gethist $id"
	::net::gets l
	if { ! [regexp {^301} $l] } {
	    error [format "protocol error on gethist: %s" $l]
	}
	set history ""
	for { ::net::gets l } { $l != "." } { ::net::gets l } {
	    if { [regexp {^([0-9]+) (.*)} $l whole stamp rest] } {
		set l [format "%s %s" [clock format $stamp] $rest]
	    }
	    set history [format "%s%s\n" $history $l]
	}
	return $history
    }

    proc addHist { id lines } {

	::net::puts "addhist $id"
	::net::gets l
	if {! [regexp "^302 " $l]} {
	    error [format "protocol error on addhist for %s: %s" $id $l]
	}
	::net::puts $lines
	::net::puts "."
	::net::gets l
	if {! [regexp "^200 " $l]} {
	    error [format "error submitting history %s: %s" $id $l]
	}
    }

    proc setState { id state } {

	::net::puts "setstate $id $state"
	::net::gets l
	if {! [regexp "^200 " $l]} {
	    error [format "error setting state for %s: %s" $id $l]
	}
    }

    proc getCommunity { router } {
	variable community

	if { [info exists community($router)] } {
	    return $community($router)
	}

	::net::puts "community $router"
	::net::gets
	if {! [regexp "^201 " $l]} {
	    error [format "error getting community for %s: %s" $router $l]
	}
	set list [split $l]
	set c [lindex $list 1]
	set community($router) $c
	return $c
    }

    proc pollRouter { router } {

	::net::puts "pollrtr $router"
	::net::gets l
	if {! [regexp "^200 " $l]} {
	    error [format "error polling router %s: %s" $router $l]
	}
    }

    proc pollIntf { router intf } {

	::net::puts "pollintf $router $intf"
	::net::gets l
	if {! [regexp "^200 " $l]} {
	    error [format "error polling interface %s / %s: %s" \
		    $router $intf $l]
	}
    }

    proc clearFlap { router intf } {

	::net::puts "clearflap $router $intf"
	::net::gets l
	if {! [regexp "^200 " $l]} {
	    error [format "error clearing flap %s / %s: %s" \
		    $router $intf $l]
	}
    }

}