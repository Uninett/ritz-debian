#
# $Id$
#

# Asynchronous sparse-walk routines

namespace eval ::just {
    namespace export sparseTableWalk
    namespace export setSparseWalkEHandler unsetSparseWalkEHandler

    variable eHandler

    # the error handler should expect to be called as
    # $eHandler $handle $error

    proc setSparseWalkEHandler { handler } {
	variable eHandler

	set eHandler $handler
    }

    proc unsetSparseWalkEHandler { } {
	variable eHandler

	catch { unset eHandler }
    }

    proc sparseTableWalk { sh varName varList body { endscript "" } } {

	foreach v $varList {
	    set oid [mib oid $v]
	    lappend oidList $oid
	    # Record the length of each OID for later.
	    lappend lenList [string length $oid]
	}
	
	$sh getnext $oidList [list \
		::just::processRow "%S" "%E" {{%V}} \
		$oidList $oidList $lenList \
		$varName $body $endscript ]
	return
    }

    proc processRow {
	sh err vblList thisRow oidList lenList varName body endscript
    } {
	variable eHandler

	if { $err != "noError" } {
	    if [info exists eHandler] {
		$eHandler $sh $err
	    } else {
		error $err;
	    }
	}

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
	    if { $endscript != "" } {
		uplevel $endscript
	    }
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
