#
# $Id$
#

catch { namespace delete ::notify }

namespace eval ::notify {
    namespace export open close

    variable acceptchan notifychan
    variable h_State h_Attr h_History h_Log h_Scavenged

    # Open notify connection and set up handlers.
    # Precondition: server channel must already be open.

    proc open { handleState handleAttr \
	    handleHistory handleLog \
	    handleScavenged handleLostConn } {
	variable h_State h_Attr h_History h_Log h_Scavenged h_LostConn
	varaible acceptchan

	foreach s "State Attr History Log Scavenged LostConn" {
	    if [info exists h_$s] {
		error "notify connection already open"
	    }
	    set h_$s [set handle$s]
	}
	if [info exists acceptchan] {
	    error "another notify connection open already in progress"
	}
	set nas [socket -server accept 0]
	set acceptchan $nas
	set port [lindex [fconfigure $nas -sockname] 2]
	::net::puts [format "nsocket %s" $port]
	::net::gets l
	if {! [regexp "^200 " $l]} {
	    error [format "error setting up notify channel: %s" $l]
	}
    }

    # Close notify connection, reset variables etc.

    proc close { } {
	variable h_State h_Attr h_History h_Log h_Scavenged h_LostConn
	variable notifychan acceptchan

	foreach s "State Attr History Log Scavenged LostConn" {
	    catch { unset h_$s }
	}
	foreach c "notify accept" {
	    set v [format "%schan" $c]
	    catch { close [set $v] }
	    catch { unset $v }
	}
    }

    # Internal routine, used to accept a notify connection.

    proc accept { chan addr port } {
	variable notifychan
	variable acceptchan

	set notifychan $chan
	fconfigure $chan -buffering line
	fileevent $chan readable [list handle $chan]

	close $acceptchan
	unset acceptchan
    }

    # Handle a notification.

    proc handle { chan } {
	global errorInfo
	variable h_LostConn

	if { [catch { doHandle $chan } msg] } {
	    if { [regexp "lost connection" $msg] } {
		$h_LostConn
		error [format "%s.  Lost server connection." $msg]
	    } else {
		error [format "error in notify::doHandle: %s" $msg]
	    }
	}
    }

    # Actually call notification handlers.

    proc doHandle { chan } {
	variable h_State h_Attr h_History h_Log h_Scavenged
	
	::net::gets l

	set id [lindex $l 0]
	set what [lindex $l 1]

	switch -exact $what {
	    state {
		$h_State $id
	    }
	    attr {
		$h_Attr $id
	    }
	    history {
		$h_History $id
	    }
	    log {
		$h_Log $id
	    }
	    scavenged {
		$h_Scavenged $id
	    }
	    default {
		error [format "unknown notify entry: %s for id %s" $what $id]
	    }
	}
    }
    
}