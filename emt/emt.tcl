#
# $Id$
#

#
# E-mail trigger client.
# Sends e-mail notification on "significant events".
#

# XXX convert to use common routines...

proc main {} {
    global allCases filteredCases sortedCases
    global Authenticated
    global Secret User Server Port
    global AllowClearTextAuth

    if { [file exists ~/.ritz.tcl] } {
	source ~/.ritz.tcl
    }

    if { ![info exists AllowClearTextAuth] } {
	# the most secure setting
	set AllowClearTextAuth 0
    }

    set sortedCases {}
    set allCases {}
    set filteredCases {}
    
    for v in "Server Port User Secret" {
	if { ![info exists $v] } {
	    error [format "%s variable not set" $v]
	}
    }

    openServer $Server $Port    
    authUser $User $Secret

    notifyOpen handleNotify
    

}