#
# $Id$
#

catch { namespace delete ::auth }

namespace eval ::auth {
    namespace export login
    namespace export challenge AllowClearTextAuth

    variable challenge
    variable authenticated
    variable AllowClearTextAuth
    set AllowClearTextAuth 0


    proc login { user secret } {
	variable challenge
	variable AllowClearTextAuth

	set s [format "%s %s" $challenge $secret]
	set r [exec sha -t <<$s]
	::net::puts [format "user %s %s" $user $r]
	if {! [regexp "^200" $l] } {
	    if { $AllowClearTextAuth } {
		::net::puts [format "user %s %s" $user $secret]
		::net::gets l
		if {! [regexp "^200" $l] } {
		    error [format "user %s login failed: %s" $user $l]
		}
	    } else {
		error [format "user %s login failed: %s" $user $l]
	    }
	}
    }

    proc reset { } {
	variable challenge

	unset challenge
	unset authenticated
    }

}
