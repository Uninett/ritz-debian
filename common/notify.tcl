#
# $Id$
#

catch { namespace delete ::notify }

namespace eval ::notify {
    namespace export open close

    variable acceptchan notifychan
    variable h_notify

    # Open notify connection and set up handlers.
    # Precondition: server channel must already be open.

    proc open { handleNotify } {
	variable h_notify
	varaible acceptchan

	if [info exists h_notify] {
	    error "notify connection already open"
	}
	set h_notify $handleNotify

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
	variable h_notify
	variable notifychan acceptchan

	catch { unset h_notify }
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
	variable h_notify

	if { [catch { doHandle $chan } msg] } {
	    if { [regexp "lost connection" $msg] } {
		$h_notify LostConn
		error [format "%s.  Lost server connection." $msg]
	    } else {
		error [format "error in notify::doHandle: %s" $msg]
	    }
	}
    }

    # Actually call notification handlers.

    proc doHandle { chan } {
	variable h_notify
	
	::net::gets -channel $chan l

	set id [lindex $l 0]
	set what [lindex $l 1]

	switch -exact $what {
	    state {
		$h_notify State $id
	    }
	    attr {
		$h_notify Attr $id
	    }
	    history {
		$h_notify History $id
	    }
	    log {
		$h_notify Log $id
	    }
	    scavenged {
		$h_notify Scavenged $id
	    }
	    default {
		error [format "unknown notify entry: %s for id %s" $what $id]
	    }
	}
    }
    
}