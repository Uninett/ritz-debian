#
# $Id$
#

# Asynchronous sparse-walk routines

namespace eval ::just {
    namespace export sparseTableWalk

    proc sparseTableWalk { sh varName varList body } {

	foreach v $varList {
	    set oid [mib oid $v]
	    lappend oidList $oid
	    # Record the length of each OID for later.
	    lappend lenList [string length $oid]
	}
	
	$sh getnext $oidList [list \
		::just::processRow "%S" "%E" {{%V}} \
		$oidList $oidList $lenList \
		$varName $body ]
	return
    }

    proc processRow { sh err vblList thisRow oidList lenList varName body } {

	if { $err != "noError" } { error $err; }

	set ixlist {}

	# Unpack one level of list nesting
	eval set upl $vblList

	foreach len $lenList oid $oidList vbl $upl {
	    set v [lindex $vbl 0]
	    if {[string compare $oid. [string range $v 0 $len]] == 0} {
		lappend ixList [string range $v $len end]
	    }
	}
	if {! [info exists ixList]} {
	    return; # end of table
	}

	set min [lindex [lsort -dictionary $ixList] 0]
	set thisRow {}
	set myvarlist {}
	foreach oid $oidList vbl $upl {
	    set v [lindex $vbl 0]
	    append oid $min
	    if {[string compare $oid $v] == 0} {
		lappend myvarlist $vbl
	    } else {
		lappend myvarlist {{} {} {}}
	    }
	    lappend thisRow $oid
	}

	upvar $varName var
	set var $myvarlist
	uplevel $body

	$sh getnext $thisRow [list \
		::just::processRow "%S" "%E" {{%V}} \
		$thisRow $oidList $lenList \
		$varName $body]
    }

}
