#
# $Id$
#

catch { namespace delete ::net }

namespace eval ::net {
    namespace export open close puts gets

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

    proc gets { var } {
	variable chan
	upvar $var line
	
	set cc [::gets $chan line]
	if { $cc == -1 } {
	    error [format "channel %s lost connection (eof)" $chan]
	}
	return $cc
    }
}