#
# $Id$
# 

#
# Routines for network handling (connection to server).
#

proc openServer { host port } {
    global AuthChallenge
    global ServerChan
    global Authenticated

    if { [info exists ServerChan] } {
	error [format "server connection already open on %s" $ServerChan]
    }

    set Authenticated 0
    set s [socket $host $port]
    fconfigure $s -buffering line
    safeGets $s l
    if { ! [regexp "^200" $l] } {
	error [format "protocol error in open: %s" $l]
    }
    set AuthChallenge($s) [lindex [split $l " "] 1]
    set ServerChan $s
}

proc closeServer { } {
    global NotifyConn NotifyAcceptChan NotifyHandler
    global ServerChan
    global Authenticated

    set Authenticated 0
    set chan $ServerChan
    
    if { [info exists NotifyConn] } {
	catch { close $NotifyConn }
    }
    catch { unset NotifyHandler }
    if { [info exists NotifyAcceptChan] } {
	catch { close $NotifyAcceptChan }
	unset NotifyAcceptChan
    }
    catch { puts $chan "quit" }
    catch { close $chan }
    unset ServerChan
}

# Authenticate user with given secret, use secure hash algorithm
# to avoid password-in-the-clear.

proc authUser { user secret } {
    global Authenticated
    global AuthChallenge
    global ServerChan
    global AllowClearTextAuth

    set chan $ServerChan

    set s [format "%s %s" $AuthChallenge($chan) $secret]
    set r [exec sha <<$s]
    safePuts $chan [format "user %s %s" $user $r]
    safeGets $chan l
    if {! [regexp "^200" $l]} {
	if { $AllowClearTextAuth } {
	    safePuts $chan [format "user %s %s" $user $secret]
	    safeGets $chan l
	    if {! [regexp "^200" $l]} {
		error [format "user %s auth failed: %s" $user $l]
	    }
	} else {
	    error [format "user %s auth failed: %s" $user $l]
	}
    }
    set Authenticated 1
}

# Error handling (e.g. closing server connection) is left
# to the higher layers.

proc safePuts { chan str } {

#    puts [format "-> %s" $str]
    if { [catch { puts $chan $str } msg ] } {
	error [format "channel %s lost connection: %s" $chan $msg]
    }
}

# Note: does not work well with non-blocking channels, which
# can return "-1" if insufficient data is available.

proc safeGets { chan var } {
    upvar $var line
    
    set cc [gets $chan line]
    if { $cc == -1 } {
	error [format "channel %s lost connection (eof)" $chan]
    }
#    puts [format "<- %s" $line]
    return $cc
}

# individual protocol-specific functions

proc pullCaseIds { } {
    global ServerChan

    set chan $ServerChan

    set caseids {}
    safePuts $chan "caseids"
    safeGets $chan l
    if { ! [regexp {^304} $l] } {
	error [format "protocol error in caseids: %s" $l]
    }
    for { safeGets $chan l } { $l != "." } { safeGets $chan l } {
	lappend caseids $l
    }
    return $caseids
}

proc getAttrs { id } {
    set attrs Attrs_$id
    global $attrs
    global ServerChan

    set chan $ServerChan

    safePuts $chan "getattrs $id"
    safeGets $chan l
    if { ! [regexp {^303} $l] } {
	error [format "protocol error in getattrs: %s" $l]
    }
    for { safeGets $chan l } { $l != "." } { safeGets $chan l } {
	if { ! [regexp {^([^:]+): (.*)$} $l x attr val] } {
	    error [format "indiscernible value in getattrs: %s" $l]
	}
	set [set attrs]($attr) $val
    }
}

proc cleanLog { log } {

    set newlog ""
    foreach le $log {
	regexp {^([0-9]+) (.*)$} $le whole stamp rest
	if { [regexp {changed state from.* on ([0-9]+)} $rest whole when] } {
	    set when_str [clock format $when]
	    regsub {(on [0-9]+)} $rest [format "on %s" $when_str] rest
	}
	set line [format "%s: %s\n" [clock format $stamp] $rest]
	set newlog [format "%s%s" $newlog $line]
    }
    return $newlog
}

proc getLog { id } {
    global ServerChan

    set chan $ServerChan

    safePuts $chan "getlog $id"
    safeGets $chan l
    if { ! [regexp {^300} $l] } {
	error [format "protocol error in getlog: %s" $l]
    }
    set log ""
    for { safeGets $chan l } { $l != "." } { safeGets $chan l } {
	lappend log $l
    }
    return [cleanLog $log]
}

proc getHist { id } {
    global ServerChan

    set chan $ServerChan

    safePuts $chan "gethist $id"
    safeGets $chan l
    if { ! [regexp {^301} $l] } {
	error [format "protocol error on gethist: %s" $l]
    }
    set history ""
    for { safeGets $chan l } { $l != "." } { safeGets $chan l } {
	if { [regexp {^([0-9]+) (.*)} $l whole stamp rest] } {
	    set l [format "%s %s" [clock format $stamp] $rest]
	}
	set history [format "%s%s\n" $history $l]
    }
    return $history
}

proc addHist { id lines } {
    global ServerChan

    set chan $ServerChan

    safePuts $chan "addhist $id"
    safeGets $chan l
    if {! [regexp "^302 " $l]} {
	error [format "protocol error on addhist for %s: %s" $id $l]
    }
    safePuts $chan $lines
    safePuts $chan "."
    safeGets $chan l
    if {! [regexp "^200 " $l]} {
	error [format "error submitting history %s: %s" $id $l]
    }
}

proc setState { id state } {
    global ServerChan

    set chan $ServerChan

    safePuts $chan [format "setstate %s %s" $id $state]
    safeGets $chan l
    if {! [regexp "^200 " $l]} {
	error [format "error setting state for %s: %s" $id $l]
    }
}

proc getCommunity { router } {
    global ServerChan
    global Community

    if { [info exists Community($router)] } {
	return $Community($router)
    }

    set chan $ServerChan
    safePuts $chan [format "community %s" $router]
    safeGets $chan l
    if {! [regexp "^201 " $l]} {
	error [format "error getting community for %s: %s" $router $l]
    }
    set list [split $l]
    return [lindex $list 1]
}

proc pollRouter { router } {
    global ServerChan

    set chan $ServerChan
    safePuts $chan [format "pollrtr %s" $router]
    safeGets $chan l
    if {! [regexp "^200 " $l]} {
	error [format "error polling router %s: %s" $router $l]
    }
}

proc pollIntf { router intf } {
    global ServerChan

    set chan $ServerChan
    safePuts $chan [format "pollintf %s %s" $router $intf]
    safeGets $chan l
    if {! [regexp "^200 " $l]} {
	error [format "error polling interface %s / %s: %s" \
		$router $intf $l]
    }
}

proc clearFlap { router intf } {
    global ServerChan

    set chan $ServerChan
    safePuts $chan [format "clearflap %s %s" $router $intf]
    safeGets $chan l
    if {! [regexp "^200 " $l]} {
	error [format "error clearing flap %s / %s: %s" \
		$router $intf $l]
    }
}

# Open a notify connection to the server on channel $chan,
# remember association so that closeServer can close the notify
# socket as well.

proc notifyOpen { handler } {
    global NotifyConn
    global NotifyHandler
    global NotifyAcceptChan
    global ServerChan

    set chan $ServerChan
    
    if { [info exists NotifyHandler] } {
	error [format "notify connection already open on %s" $chan]
    }
    if { [info exists NotifyAcceptChan] } {
	error [format "another notify connection open already in progress"]
    }
    # create a temporary server socket to implement the passive open
    set nas [socket -server notifyAccept 0]
    set NotifyAcceptChan $nas
    set NotifyHandler $handler

    set port [lindex [fconfigure $nas -sockname] 2]
    safePuts $chan [format "nsocket %s" $port]
    safeGets $chan l
    if {! [regexp "^200 " $l]} {
	error [format "error setting up notify channel: %s" $l]
    }
}

proc notifyAccept { chan addr port } {
    global NotifyConn
    global NotifyHandler
    global NotifyAcceptChan
    global ServerChan

#    puts [format "notifyAccept entered: chan %s addr %s port %s" \
#	    $chan $addr $port]
    set NotifyConn $chan
    fconfigure $chan -buffering line
    fileevent $chan readable [list $NotifyHandler $chan]

    close $NotifyAcceptChan
    unset NotifyAcceptChan
#    puts [format "Accepted notify connection, chan %s" $chan]
}
