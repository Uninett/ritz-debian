#
# $Id$
#

#
# Procedure(s) to handle notify channel
# and the local database of cases
#

proc doHandleNotify { chan } {

    safeGets $chan l
#    puts [format "notify: %s" $l]
    set id [lindex $l 0]
    set what [lindex $l 1]

    if { [unknownCase $id] } {
	if { $what != "state" } {
#	    puts [format "case %s waiting for state update" $id]
	    return;		# wait for "state" entry
	}
	addCase $id
    }

    switch -exact $what {
	state {
	    getAttrs $id
	    if { [winfo exists .hist$id] } {
		uiViewHist $id
	    }
	    if { [winfo exists .case$id] } {
		uiViewCase $id
	    }
	}
	attr {
	    getAttrs $id
	    if { [winfo exists .case$id] } {
		uiViewCase $id
	    }
	}
	history {
	    if { [winfo exists .hist$id] } {
		uiViewHist $id
	    }
	}
	log {
	    if { [winfo exists .log$id] } {
		uiViewLog $id
	    }
	}
	scavenged {
	    removeCase $id
	}
	default {
	    error [format "unknown notify entry: %s for id %s" $what $id]
	}
    }
    scheduleUpdateDisplay 5
}

proc handleNotify { chan } {
    global errorInfo

    if { [catch { doHandleNotify $chan } msg] } {
	if { [regexp "lost connection" $msg] } {
	    uiCloseServer
	    error [format "%s.  Closed server connection." $msg]
	} else {
	    error [format "error in handleNotify: %s" $msg]
	}
    }
}

proc removeFromList { id listname } {
    upvar $listname list

    set new {}
    foreach i $list {
	if { $i != $id } {
	    lappend new $i
	}
    }
    set list $new
}

proc pullCases { } {
    global knownCase

    set ids [pullCaseIds]
    foreach id $ids {
	getAttrs $id
	set knownCase($id) 1
    }
    return $ids
}

# Update the display, consider changes caused by notification.

proc scheduleUpdateDisplay { secs } {
    
    after cancel updateDisplay
    after [expr $secs * 1000] updateDisplay
}

proc updateDisplay { } {
    global allCases filteredCases sortedCases

    set filteredCases [filterCases $allCases]
    set sortedCases [sortCases $filteredCases]

    # Schedule an update in 5 seconds if no new events
    # arrive before that time.
    uiScheduleSummaryUpdate 5
}

proc removeCase { id } {
    global knownCase
    global sortedCases

    catch { AttrForget $id }
    catch { unset knownCase($id) }
    foreach l {allCases filteredCases sortedCases} {
	global $l
	removeFromList $id $l
    }
    uiScheduleSummaryUpdate 5
}

proc unknownCase { id } {
    global knownCase

    return [expr ! [info exists knownCase($id)]]
}

proc addCase { id } {
    global allCases filteredCases sortedCases
    global knownCase

    getAttrs $id
    set knownCase($id) 1
    lappend allCases $id
    scheduleUpdateDisplay 5
}
