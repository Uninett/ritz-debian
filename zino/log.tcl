#
# $Id$
#

proc secsToStamp { secs } {
    return [clock format $secs -format "%a %b %d %H:%M:%S %Y"]
}

proc getStamp {} {
    return [secsToStamp [clock seconds]]
}

proc logerr { str } {
    set stamp [getStamp]
    puts stderr [format "%s: %s" $stamp $str]
}

proc log_str { str } {
    set stamp [getStamp]
    return [format "%s: %s" $stamp $str]
}

set log_chans(stdout) 1

proc log { str } {
    global log_chans

    foreach chan [array names log_chans] {
	if { [catch { puts $chan [log_str $str] }] } {
	    unset log_chans($chan)
	}
    }
}

proc newConn { chan host port } {
    global log_chans
    fconfigure $chan -buffering line
    set log_chans($chan) 1
}

if { [info exists ssock] } {
    close $ssock
}
set ssock [socket -server newConn 8000]

set detailEventLogLimit 30

proc detailLog { rtr ix str } {
    global detailEventLog detailEventLogLimit

    if { [info exists detailEventLog($rtr,$ix)] && \
	    [llength $detailEventLog($rtr,$ix)] >= $detailEventLogLimit } {
	set detailEventLog($rtr,$ix) [lrange $detailEventLog($rtr,$ix) 1 end]
    }
    lappend detailEventLog($rtr,$ix) [log_str $str]
}

proc dumpDetailLog { ix } {
    global detailEventLog    

    puts $ix
    foreach le $detailEventLog($ix) {
	puts [format " %s" $le]
    }
}

proc dumpDetailLogs { } {
    global detailEventLog

    foreach ix [array names detailEventLog] {
	dumpDetailLog $ix
    }
}

proc dumpstr { s } {
    set l [split $s ""]
    set pfx ""
    foreach c $l {
	scan $c %c c
	puts -nonewline [format "%s%x" $pfx $c]
	set pfx " "
    }
    puts ""
}

proc readAndDump { chan } {
    if { [gets $chan line] == -1 } {
	close $chan
	return 0
    }
    dumpstr $line
    puts $line
}
