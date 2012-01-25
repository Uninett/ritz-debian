#
# $Id$
#

catch { namespace delete ::slave }

namespace eval ::slave {
    namespace export initSlave

    variable master_handle
    variable master_socket notify_socket master_address
    variable master_uptime
    variable slave_user slave_secret

    proc initSlave { master user secret } {
	variable master_handle master_address
	variable slave_user slave_secret
	
	set slave_user $user
	set slave_secret $secret
	set master_address $master

	set master_handle \
	    [snmp session \
		 -address $master \
		 -version SNMPv2c \
		 -port 8000]
	job create \
	    -interval 30000 \
	    -command [list checkMaster $master_handle]
    }

    proc checkMaster { handle } {

	$handle get zinoUpTime.0 {
	    if { "%E" != "noError" } {
		shutdownMaster "SNMP error: %E"
	    }
	    validateUptime "%V"
	}
    }

    proc validateUptime { vbl } {
	variable master_uptime
	
	set new_uptime [lindex [lindex $vbl 0] 2]

	if { [info exists master_uptime] } {
	    # Re-initialized master?
	    if { $new_uptime < $master_uptime } {
		shutdownMaster "master restarted"
	    }
	}
	ensureOpenMaster
	set master_uptime $new_uptime
    }

    proc shutdownMaster { err } {
	variable master_socket notify_socket

	log [format "Closing master connection due to: %s" $err]
	catch { close $master_socket }
	catch { close $notify_socket }
	unset master_socket;	# mark not connected
    }

    proc ensureOpenMaster { } {
	variable master_socket

	if { ! [info exists master_socket] } {
	    set master_socket [openMaster]
	    openNotifySocket
	}
    }

    proc openMaster { } {
	variable master_address
	variable slave_user slave_secret

	set s [socket $master_address 8001]
	fconfigure $s -buffering line
	gets $s l
	if { ! [regexp "^200" $l] } {
	    error [format "protocol error in master open: %s" $l]
	}
	set challenge [lindex [split $l " "] 1]
	set str [format "%s %s" $challenge $slave_secret]
	set r [exec %SHA% <<$str]
	puts $s [format "user %s %s" $slave_user $r]
	gets $s l
	if {! [regexp "^200" $l]} {
	    error [format "Error logging in: %s" $l]
	}

	return $s
    }

    proc openNotifySocket { } {
	variable master_socket master_address
	variable notify_socket

	set s $master_socket
	
	set notify_socket [socket $master_address 8002]
	gets $notify_socket nonce
	puts $s [format "ntie %s" $nonce]
	gets $s l
	if { ! [regexp "^200" $l] } {
	    error [format "Error setting up notify socket: %s" $l]
	}
	fconfigure $notify_socket -buffering line
	fileevent $notify_socket readable [list handleNotify $notify_socket]
    }

    proc handleNotify { ns } {

	gets $ns l
	set id [lindex $l 0]
	set what [lindex $l 1]
	# fill in with getting attrs, extract IX for event and admin-state
	# ...and track changes.
    }
}