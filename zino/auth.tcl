#
# $Id$
#

#
# Authentication module.
# Possible authentication methods:
#
# 1) challenge/response based using common secrets and SHA
# 2) clear-text passwords, stored in their SHAed form together with
#    the "real" secrets
# 3) use of (extended) tacacs
#
# Needless to say, it is only the first one which is safe from
# wiretapping.
#


proc initAuth { fn } {
    global authFile

    set authFile $fn
}

proc authChallenge { chan } {
    global authChallenge
    
    set ch [exec date | sha -t]
    set authChallenge($chan) $ch
    return $ch
}

proc authReadUsers { fn } {
    global authSecret

    set f [open $fn "r"]
    while { [gets $f line] != -1 } {
	set l [split $line " "]
	set user [lindex $l 0]
	set secret [lindex $l 1]
	set authSecret($user) $secret
    }
    close $f
}

proc authPass { chan user resp } {
    global authFile
    global authChallenge
    global authSecret
    global authClearTextPasswords
    global authTacacs Tacping Tachost
    
#puts [format "authPass %s %s %s" $chan $user $resp]
    
    authReadUsers $authFile
    if { ! [info exists authSecret($user)] && ! $authTacacs } {
	error "Authentication failure (no such user)"
    }

    # compute SHA(challenge+secret), compare to response
    set s [format "%s %s" $authChallenge($chan) $authSecret($user)]
    set r [exec sha -t <<$s]
    if { $r == $resp } {
	return
    }

    # compute SHA(response), compare to stored secret
    # This is to handle clear-text passwords, and may be disabled.
    if { $authClearTextPasswords } {
	set r [exec sha -t <<$resp]
	if { $r == $authSecret($user) } {
	    return
	}
    }

    # check tacacs response if configured
    if { $authTacacs } {
	set l [list [format "%s" $Tacping] -p $resp -u $user $Tachost]
#	puts [format "%s" [join $l]]
	set r [eval exec $l]
#	puts $r
#	puts [lindex $r 2]
	if {[lindex $r 2] == "(accepted),"} {
	    return
	}
    }

    error "Authentication failure"
}
