#
# $Id$
#

catch { namespace delete ::net }

namespace eval ::net {
    namespace export open close puts gets

    # Server connection
    variable chan


    proc open { host port } {
	variable chan
	variable ::auth::challenge

	if { [info exists chan] } {
	    error [format "server connection already open on %s" $chan]
	}
	set s [socket $host $port]
	fconfigure $s -buffering line
	gets $s l
	if { ! [regexp "^200" $l] } {
	    error [format "protocol error in open: %s" $l]
	}
	set ::auth::challenge [lindex [split $l " "] 1]
	set chan $s
    }

    proc close { } {
	variable chan

	::auth::reset
	::notify::close
	catch { ::puts $chan "quit"}
	catch { ::close $chan }
	unset chan
    }

    proc puts { str } {
	variable chan

	if { [catch { ::puts $chan $str } msg ] } {
	    error [format "channel %s lost connection: %s" $chan $msg]
	}
    }

    proc gets { args } {

	if { [lindex $args 0] == "-channel" } {
	    set ch [lindex $args 1]
	    set var [lindex $args 2]
	} else {
	    variable chan
	    set ch $chan
	    set var [lindex $args 0]
	}
	upvar $var line
	
	set cc [::gets $ch line]
	if { $cc == -1 } {
	    error [format "channel %s lost connection (eof)" $ch]
	}
	return $cc
    }
}