#
# $Id$
#

#
# Server module, handling connections and commands from clients.
#

package require Tclx

if { [info exists ServerSocket] } {
    close $ServerSocket
}
set ServerSocket [socket -server newServerConn 8001]

proc newServerConn { chan host port } {
    global ClientHost ClientPort
    
    fconfigure $chan -buffering line
    fconfigure $chan -blocking false
    fcntl $chan KEEPALIVE 1

    ClientResponse $chan [format "200 %s Hello, there" [authChallenge $chan]]

    set ClientHost($chan) $host
    set ClientPort($chan) $port

    fileevent $chan readable [list readServerCmd $chan]
}

proc readServerCmd { chan } {

    if { [catch { set cc [gets $chan line] } msg] } {
	closeClient $chan $msg
	return
    }
    if { $cc == 0 || $cc == -1} {
	if { [eof $chan] } {
	    closeClient $chan "Lost connection"
	}
	return
    }
    ServerCmd $chan $line
}

proc closeClient { chan msg } {
    global ClientHost ClientPort ClientNotify
    global User

    catch { unset User($chan) }
    catch { unset ClientHost($chan) }
    catch { unset ClientPort($chan) }
    if { [info exists ClientNotify($chan)] } {
	set s $ClientNotify($chan)
	catch { puts $s $msg }
	close $ClientNotify($chan)	
	unset ClientNotify($chan)
    }
    catch { close $chan }
}

proc ClientResponse { chan msg } {
    if { [catch {puts $chan $msg}] } {
	closeClient $chan "Lost client connection, shutting down"
    }
}

proc errResponse { chan msg } {
    ClientResponse $chan [format "500 %s" $msg]
}

proc okResponse { chan } {
    ClientResponse $chan "200 ok"
}

# Implement server commands, dispatched from ServerCmd.

proc doUserCmd { chan l } {
    global User

    if { [info exists User($chan)] } {
	errResponse $chan "already authenticated"
	return
    }
    if { [llength $l] < 3 } {
	errResponse $chan \
		"user needs 2 parameters (user, response)"
	return
    }
    set user [lindex $l 1]
    set response [lindex $l 2]
    if { [catch {authPass $chan $user $response} msg] } {
	errResponse $chan $msg
	return
    }
    set User($chan) $user
    okResponse $chan
}

proc doNsocketCmd { chan l } {
    global User
    global OpenServerAccess
    global ClientHost

    if { ! $OpenServerAccess && ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan "nsocket needs 1 parameter (portno)"
	return
    }
    set rport [lindex $l 1]
    if { [catch { \
	    openNotifyConn $chan $ClientHost($chan) $rport} msg]} {
	errResponse $chan $msg
    } else {
	okResponse $chan
    }
}

proc doCaseidsCmd { chan l } {
    global User
    global OpenServerAccess

    if { ! $OpenServerAccess && ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    set ids [eventIds]
    ClientResponse $chan \
	    "304 list of active cases follows, terminated with '.'"
    foreach id [lsort -integer -increasing $ids] {
	ClientResponse $chan $id
    }
    ClientResponse $chan "."
}

proc doGetattrsCmd { chan l } {
    global User
    global OpenServerAccess

    if { ! $OpenServerAccess && ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan "getattrs needs 1 parameter (case-id)"
	return
    }
    set id [lindex $l 1]
    if { ! [eventExists $id] } {
	errResponse $chan [format "event \"%s\" does not exist" $id]
	return
    }
    ClientResponse $chan \
	    "303 simple attributes follow, terminated with '.'"
    dumpEventAttrs $chan $id ClientResponse
    ClientResponse $chan "."
}

proc doGetlogCmd { chan l } {
    global User
    global OpenServerAccess

    if { ! $OpenServerAccess && ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan "getlog needs 1 parameter (case-id)"
	return
    }
    set id [lindex $l 1]
    if { [catch {set log [getEventAttr $id log]} msg ] } {
	errResponse $chan $msg
	return
    }
    ClientResponse $chan "300 log follows, terminated with '.'"
    foreach line $log {
	ClientResponse $chan $line
    }
    ClientResponse $chan "."
}

proc doGethistCmd { chan l } {
    global User
    global OpenServerAccess

    if { ! $OpenServerAccess && ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan "getlog needs 1 parameter (case-id)"
	return
    }
    set id [lindex $l 1]
    if { [catch {set hist [getEventAttr $id history]} msg ] } {
	errResponse $chan $msg
	return
    }
    ClientResponse $chan "301 history follows, terminated with '.'"
    foreach line $hist {
	ClientResponse $chan $line
    }
    ClientResponse $chan "."
}

proc doAddhistCmd { chan l } {
    global User
    global OpenServerAccess
    global SaveHandler
    global MultiEndCmd

    if { ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan "addhist needs 1 parameter (case-id)"
	return
    }
    set id [lindex $l 1]
    set SaveHandler($chan) [fileevent $chan readable]
    fileevent $chan readable [list multiRead $chan]
    ClientResponse $chan \
	    "302 please provide new history entry, termiate with '.'"
    set MultiEndCmd($chan) [list endAddHist $chan $id]
}

proc doSetstateCmd { chan l } {
    global User

    if { ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 3 } {
	errResponse $chan \
		"setattr needs 2 parameters (case-id, value)"
	return
    }
    set id [lindex $l 1]
    set state [lindex $l 2]
    if { [catch { setEventAttr $id state $state $User($chan) } msg] } {
	errResponse $chan $msg
	return
    }
    if { [catch { eventCommit $id } msg] } {
	errResponse $chan $msg
	return
    }
    okResponse $chan
}

proc doCommunityCmd { chan l } {
    global User

    if { ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan \
		"community needs 1 parameter (router)"
	return
    }
    set router [lindex $l 1]
    ClientResponse $chan [format "201 %s" [::config::conf $router community]]
}

proc doPollIntfCmd { chan l } {
    global User

    if { ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 3 } {
	errResponse $chan \
		"pollintf needs 2 parameters (router ifindex)"
	return
    }
    set router [lindex $l 1]
    set intf [lindex $l 2]
    if { ! [knownRouter $router] } {
	errResponse $chan [format "Router %s unknown"]
	return
    }
    pollSingleIf [handle $router] $intf
    okResponse $chan
}

proc doPollRtrCmd { chan l } {
    global User

    if { ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan \
		"pollrtr needs 1 parameter (router)"
	return
    }
    set router [lindex $l 1]
    if { ! [knownRouter $router] } {
	errResponse $chan [format "Router %s unknown" $router]
	return
    }
    pollRouter $router
    okResponse $chan
}

proc doClearFlap { chan l } {
    global User

    if { ! [info exists User($chan)] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 3 } {
	errResponse $chan \
		"clearflap needs 2 parameters (router ifindex)"
	return
    }
    set router [lindex $l 1]
    set intf [lindex $l 2]
    if { ! [knownRouter $router] } {
	errResponse $chan [format "Router %s unknown"]
	return
    }
    clearFlap $router $intf $User($chan)
    okResponse $chan
}

proc doQuitCmd { chan l } {

    ClientResponse $chan "205 Bye"
    closeClient $chan "Normal quit from client, closing down"
}

proc doVersionCmd { chan l } {
    global Version

    ClientResponse $chan [format "200 zino version is %s" $Version]
}

proc doHelpCmd { chan l } {
    global User
    global OpenServerAccess

    ClientResponse $chan "200- commands are:"
    if { $OpenServerAccess && ! [info exists User($chan)] } {
	ClientResponse $chan \
		"200- CASEIDS GETATTRS GETHIST"
	ClientResponse $chan\
		"200  GETLOG HELP NSOCKET QUIT USER VERSION"
    } elseif { [info exists User($chan)] } {
	ClientResponse $chan \
		"200- ADDHIST CASEIDS CLEARFLAP COMMUNITY GETATTRS GETHIST"
	ClientResponse $chan \
		"200-  GETLOG HELP NSOCKET POLLINTF POLLRTR QUIT SETSTATE"
	ClientResponse $chan \
	        "200   VERSION"
    } else {
	ClientResponse $chan "200  HELP QUIT USER VERSION"
    }
}

proc ServerCmd { chan line } {

    set l [split $line " "]
    switch -exact [string tolower [lindex $l 0]] {
	user {
	    doUserCmd $chan $l
	}
	nsocket {
	    doNsocketCmd $chan $l
	}
	caseids {
	    doCaseidsCmd $chan $l
	}
	clearflap {
	    doClearFlap $chan $l
	}
	getattrs {
	    doGetattrsCmd $chan $l
	}
	getlog {
	    doGetlogCmd $chan $l
	}
	gethist {
	    doGethistCmd $chan $l
	}
	addhist {
	    doAddhistCmd $chan $l
	}
	setstate {
	    doSetstateCmd $chan $l
	}
	community {
	    doCommunityCmd $chan $l
	}
	pollintf {
	    doPollIntfCmd $chan $l
	}
	pollrtr {
	    doPollRtrCmd $chan $l
	}
	quit {
	    doQuitCmd $chan $l
	}
	help {
	    doHelpCmd $chan $l
	}
	version {
	    doVersionCmd $chan $l
	}
	default {
	    errResponse $chan \
		    [format "unknown command: \"%s\"" [lindex $l 0]]
	}
    }
}

proc multiRead { chan } {
    global MultiEndCmd
    global MultiLines
    global SaveHandler

    if { [catch { set cc [gets $chan line] }] } {
	closeClient $chan
	return
    }
    if { $cc == 0 || $cc == -1 } {
	if { [eof $chan] } {
	    closeClient $chan
	}
	return
    }
    if { ! [info exists MultiLines($chan)] } {
	set MultiLines($chan) ""
    }
    if { $line == "." } {
	if { [info exists MultiEndCmd($chan)] } {
#	    puts [format "multi-read end:\n%s" $MultiLines($chan)]
	    eval $MultiEndCmd($chan) MultiLines($chan)
	}
	fileevent $chan readable $SaveHandler($chan)
	unset MultiLines($chan)
	return
    }
    # just append, wait for terminating '.'
    set MultiLines($chan) [format "%s%s\n" $MultiLines($chan) $line]
#    puts [format "MultiRead intermediate result (cc=%s) --" $cc]
#    puts [format "%s" $MultiLines($chan)]
#    puts [format "--"]
}

proc endAddHist { chan id var } {
    global User
    upvar $var lines

    if { [info exists User($chan)] } {
	set user $User($chan)
    } else {
	set user "unknown"
    }

#    puts [format "history: %s\n--" $lines]
    if { [catch { eventHistoryAdd $id $user $lines } msg] } {
	errResponse $chan $msg
	return
    }
    if { [catch { eventCommit $id } msg] } {
	errResponse $chan $msg
	return
    }
    okResponse $chan
}

# Notification (sub)module

proc openNotifyConn { chan host port } {
    global ClientNotify

    if { [info exists ClientNotify($chan)] } {
	set s $ClientNotify($chan)
	set msg [format "%s: %s" \
		"Notify connection already open to" \
		[fconfigure $s -peername]]
	error $msg
    }
    set s [socket $host $port]
    fconfigure $s -blocking false
    fconfigure $s -buffering line
    fcntl $s KEEPALIVE 1
    set ClientNotify($chan) $s
}

proc notifySend { msg } {
    global ClientNotify

    foreach clnt [array names ClientNotify] {
	set chan $ClientNotify($clnt)
	if { [catch {puts $chan $msg}] } {
	    closeClient $clnt "Lost notify connection, shutting down"
	}
#	puts [format "notify %s: %s" $chan $msg]
    }
}

proc notifyCheck { id } {
    global eventStateChange

    set txt(eventHistAdd) "history"
    set txt(eventAttrChange) "attr"
    set txt(eventLogAdd) "log"

#    puts [format "notify checking %s" $id]
    foreach g [array names txt] {
	global $g
	if { [info exists [set g]($id)] } {
	    set msg [format "%s %s %s" $id $txt($g) [set [set g]($id)]]
	    notifySend $msg
#	    puts [format "notify: %s" $msg]
	    unset [set g]($id)
	}
    }
    if { [info exists eventStateChange($id)] } {
	set msg [format "%s %s %s" $id "state" $eventStateChange($id)]
	notifySend $msg
#	puts [format "notify: %s" $msg]
	unset eventStateChange($id)
    }
}

proc notifyScavenge { id } {

    notifySend [format "%s scavenged" $id]
}
