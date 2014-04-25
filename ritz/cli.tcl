
# $Id$
#

# Simple CLI client to zino, takes care of authentication
# and allows the user to interact directly with the zino server.

proc main {} {

    global allCases filteredCases sortedCases
    global Authenticated
    global Server Port
    global AllowClearTextAuth

    global Secret User Server Port
    global _Secret _User _Server _Port

    if { [file exists ~/.smon.tcl] } {
	source ~/.smon.tcl
    }
    if { [file exists ~/.ritz.tcl] } {
	source ~/.ritz.tcl
    }
    if { ![info exists AllowClearTextAuth] } {
	# the most permissive setting
	set AllowClearTextAuth 1
    }

    openServer $Server $Port

    puts [format "Connected to %s / %s" $Server $Port]

    authUser $User $Secret

    if { $Authenticated == 1 } {
	puts [format "Authenticated as user %s" $User]
    } else {
	puts [format "Authentication as %s failed" $User]
	closeServer
	exit 1
    }
    
    global ServerChan
    set ch $ServerChan

    set cmd ""
    set n 0
    while { $cmd != "quit" && $n >= 0} {
	set n [gets stdin l]
	if { $n < 0 } { break; }
	set cmd [lindex $l 0]
	if { $cmd == "quit" } { break; }

	safePuts $ch $l
	safeGets $ch l
	puts $l
	if [regexp {^3} $l] {	# "more to come"
	    for { safeGets $ch l } { $l != "." } { safeGets $ch l } {
		puts $l
	    }
	    puts $l;		# final "."
	} elseif [regexp {^...-} $l] { # also "more to come"
	    while { [regexp {^...-} $l] } {
		safeGets $ch l
		puts $l
	    }
	}
    }
    puts "Closing server connection"
    closeServer
    exit 0
}


