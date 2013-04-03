#
# $Id$
#

#
# Server module, handling connections and commands from clients.
#

# package require Tclx

if { [info exists ServerSocket] } {
    close $ServerSocket
}
set ServerSocket [socket -server newServerConn 8001]

proc newServerConn { chan host port } {
    global ClientHost ClientPort
    
    fconfigure $chan -buffering line
    fconfigure $chan -blocking false
#    fcntl $chan KEEPALIVE 1

    ClientResponse $chan [format "200 %s Hello, there" [authChallenge $chan]]

    set ClientHost($chan) $host
    set ClientPort($chan) $port

    fileevent $chan readable [list readServerCmd $chan]

#    log [format "New server connection fd %s from %s / %s" $chan $host $port]
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
	catch { close $s }	
	unset ClientNotify($chan)
#	log [format "Closed notify channel %s" $s]
    }
    catch { close $chan }
#    log [format "Closed fd %s" $chan]
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

    if { [Authenticated $chan] } {
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
    global ClientHost

    if { ! [PermitROaccess $chan] } {
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

    if { ! [PermitROaccess $chan] } {
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

    if { ! [PermitROaccess $chan] } {
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

    if { ! [PermitROaccess $chan] } {
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
    global OpenServerAccess

    if { ! [PermitROaccess $chan] } {
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
    global SaveHandler
    global MultiEndCmd

    if { ! [Authenticated $chan] } {
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

    if { ! [Authenticated $chan] } {
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

    if { ! [Authenticated $chan] } {
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

    if { ! [Authenticated $chan] } {
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

    if { ! [Authenticated $chan] } {
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

    if { ! [Authenticated $chan] } {
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

    ClientResponse $chan "200- commands are:"
    if { [Authenticated $chan] } {
	ClientResponse $chan \
		"200- ADDHIST CASEIDS CLEARFLAP COMMUNITY GETATTRS GETHIST"
	ClientResponse $chan \
		"200- GETLOG HELP NSOCKET NTIE POLLINTF POLLRTR QUIT SETSTATE"
	ClientResponse $chan \
	        "200  PM VERSION"
    } elseif [PermitROaccess $chan] {
	ClientResponse $chan \
		"200- CASEIDS GETATTRS GETHIST"
	ClientResponse $chan\
		"200  GETLOG HELP NSOCKET NTIE QUIT USER PM VERSION"
    } else {
	ClientResponse $chan "200  HELP QUIT USER VERSION"
    }
}

proc PermitROaccess { chan } {
    global User
    global OpenServerAccess

    if { $OpenServerAccess } {
	return 1
    }
    if [Authenticated $chan] {
	return 1
    }
    return 0
}

proc Authenticated { chan } {
    global User

    return [info exists User($chan)]
}

# Commands related to Planned Maintenance

proc doPMadd { chan l } {

    if { ! [Authenticated $chan] } {
	errResponse $chan "Not authenticated"
	return
    }

    set from_t [lindex $l 2]
    set to_t   [lindex $l 3]
    set type   [string tolower [lindex $l 4]]
    set m_type [string tolower [lindex $l 5]]
    set m_expr [lindex $l 6]

    if { ! [regexp {^[0-9][0-9]*$} $from_t] } {
	errResponse $chan \
	    [format "illegal from_t (param 1), must be only digits"]
	return
    }
    if { ! [regexp {^[0-9][0-9]*$} $to_t] } {
	errResponse $chan \
	    [format "illegal to_t (param 2), must be only digits"]
	return
    }
    if { $from_t > $to_t } {
	errResponse $chan [format "ending time is before starting time"]
	return
    }
    if { $from_t < [clock seconds] } {
	errResponse $chan [format "starting time is in the past"]
	return
    }
    if { $type != "portstate" && $type != "device" } {
	errResponse $chan [format "unknown PM event type: %s" $type]
	return
    }
    if { $m_type != "regexp" && $m_type != "str" && $m_type != "exact" } {
	errResponse $chan [format "unknown match type: %s" $m_type]
	return
    }
    set id [::pm::add $from_t $to_t $type $m_type $m_expr]
    ClientResponse $chan \
	[format "200 PM id %s successfully added" $id]
}

proc doPMlist { chan l } {

    if { ! [PermitROaccess $chan] } {
	errResponse $chan "No permission"
	return
    }
    set ids [::pm::ids]
    ClientResponse $chan "300 PM event ids follows, terminated with '.'"
    foreach id $ids {
	ClientResponse $chan $id
    }
    ClientResponse $chan "."
}

proc doPMcancel { chan l } {
    global User

    if { ! [Authenticated $chan] } {
	errResponse $chan "Not authenticated"
	return
    }

    if { [info exists User($chan)] } {
	set user $User($chan)
    } else {
	set user "unknown"
    }

    set id [lindex $l 2]
    ::pm::cancel $id $user

    okResponse $chan
}

proc doPMdetails { chan l } {

    if { ! [PermitROaccess $chan] } {
	errResponse $chan "No permission"
	return
    }
    set id [lindex $l 2]
    if [catch {set det [::pm::details $id]} msg] {
	errResponse $chan [format "Could not get details for id %d" $id]
	log $msg
	return
    }
    ClientResponse $chan [format "200 %s" $det]
}

proc doPMmatching { chan l } {

    if { ! [PermitROaccess $chan] } {
	errResponse $chan "No permission"
	return
    }
    set id [lindex $l 2]
    set matches [::pm::matching $id]
    ClientResponse $chan \
	[format "300 Matching ports/devices follows, terminated with '.'"]
    foreach m $matches {
	ClientResponse $chan $m
    }
    ClientResponse $chan "."
}

proc doPMaddlog { chan l } {
    global SaveHandler
    global MultiEndCmd
    
    if { ! [Authenticated $chan] } {
	errResponse $chan "Not authenticated"
	return
    }

    if { [llength $l] < 3 } {
	errResponse $chan "PM add log needs PM id"
	return
    }
    set id [lindex $l 2]

    set SaveHandler($chan) [fileevent $chan readable]
    set MultiEndCmd($chan) [list endPMaddlog $chan $id]
    fileevent $chan readable [list multiRead $chan]
    ClientResponse $chan \
	"302 please provide new PM log entry, terminate with '.'"
}

proc endPMaddlog { chan id var } {
    global User
    upvar $var lines

    if { [info exists User($chan)] } {
	set user $User($chan)
    } else {
	set user "unknown"
    }

    ::pm::addlog $id $lines $user

    okResponse $chan
}

proc doPMlog { chan l } {

    if { ! [PermitROaccess $chan] } {
	errResponse $chan "No permission"
	return
    }

    set id [lindex $l 2]
    set l [::pm::log $id]
    ClientResponse $chan "300 log follows, terminated with '.'"
    foreach e $l {
	ClintResponse $chan $e
    }
    ClientResponse $chan "."
}

proc doPMhelp { chan l } {

    ClientResponse $chan "200- PM subcommands are:"

    if [Authenticated $chan] {
	ClientResponse $chan "200  ADD LIST CANCEL DETAILS MATCHING ADDLOG LOG"
    } elseif [PermitROaccess $chan] {
	ClientResponse $chan "200  LIST DETAILS MATCHING LOG"
    } else {
	ClientResponse $chan "200  (none allowed)"
    }
}

proc doPM { chan l } {

    switch -exact [string tolower [lindex $l 1]] {
	"add" {
	    doPMadd $chan $l
	}
	"list" {
	    doPMlist $chan $l
	}
	"cancel" {
	    doPMcancel $chan $l
	}
	"details" {
	    doPMdetails $chan $l
	}
	"matching" {
	    doPMmatching $chan $l
	}
	"addlog" {
	    doPMaddlog $chan $l
	}
	"log" {
	    doPMlog $chan $l
	}
	"help" {
	    doPMhelp $chan $l
	}
	default {
	    errResponse $chan \
		    [format "unknown PM command: \"%s\"" [lindex $l 1]]
	}
    }
}

# end of Planned Maintenance-related functions

proc ServerCmd { chan line } {

    set l [split $line " "]
    switch -exact [string tolower [lindex $l 0]] {
	user {
	    doUserCmd $chan $l
	}
	nsocket {
	    doNsocketCmd $chan $l
	}
	ntie {
	    doNtieCmd $chan $l
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
	pm {
	    doPM $chan $l
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

if { [info exists NotifyServerSocket] } {
    close $NotifyServerSocket
}

set NotifyServerSocket [socket -server newNotifyConn 8002]

proc getNonce { } {

    set n [exec dd if=/dev/urandom count=128 bs=1 2> /dev/null | %SHA%]
    return $n
}

proc newNotifyConn { chan chost cport } {
    global NotifyChan

    fconfigure $chan -buffering line
    fconfigure $chan -blocking false
#    fcntl $chan KEEPALIVE 1
    fileevent $chan readable [list NotifySink $chan]

    set n [getNonce]
    puts $chan $n

    set NotifyChan($n) $chan

#    log [format "New notify connection fd %s from %s / %s" $chan $chost $cport]

    after 30000 CheckNewNotify $n

}

proc NotifySink { chan } {
    global NotifyChan
    global ClientNotify

    set c [gets $chan l]
    if { $c == -1 } {
#	log [format "Error reading notify-channel %s, closing" $chan]
	catch { close $chan }
	foreach n [array names NotifyChan] {
	    if { $NotifyChan($n) == $chan } {
		unset NotifyChan($n)
	    }
	}
	foreach clnt [array names ClientNotify] {
	    if { $ClientNotify($clnt) == $chan } {
		closeClient $clnt "Lost notify connection, shutting down"
	    }
	}
    }
}

proc CheckNewNotify { nonce } {
    global NotifyChan

    if [info exists NotifyChan($nonce)] {
	set chan $NotifyChan($nonce)
	catch { puts $chan "Timeout waiting for action, closing..." }
	log [format "closing %s: timeout waiting for tie of notify socket" \
		 $chan]
	catch { close $chan }
	unset NotifyChan($nonce)
    }
}

proc doNtieCmd { chan l } {
    global NotifyChan
    global ClientNotify

    if { ! [PermitROaccess $chan] } {
	errResponse $chan "Not authenticated"
	return
    }
    if { [llength $l] < 2 } {
	errResponse $chan "ntie needs 1 parameter (nonce)"
	return
    }
    set nonce [lindex $l 1]

    if [info exists NotifyChan($nonce)] {
	set ClientNotify($chan) $NotifyChan($nonce)
	unset NotifyChan($nonce)
	okResponse $chan
	return
    }
    errResponse $chan "Could not find your notify socket"
}

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
#    fcntl $s KEEPALIVE 1
    fileevent $s readable [list NotifySink $s]
    set ClientNotify($chan) $s

#    log [format "Notify connection fd %s from %s / %s" $chan $host $port]
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
