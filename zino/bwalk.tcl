#
# $Id$
#

#
# Set of functions to do a single-variable GET-BULK with the given
# number of repetitions, with optional end-of-varlist and error handlers.
#

proc processBulk { sh vbl err start_oid reps action args } {

    if { $err == "noError" } {
	set himatch "";		# highest matching oid, use in next getbulk
	set eov 0
	set fvbl {};		# filtered variable binding list
	foreach vb $vbl {
	    set oid [lindex $vb 0]
	    if [oidPfxMatch $start_oid $oid] {
		set himatch $oid
		lappend fvbl $vb
	    } else {
		set eov 1;	# end of matching variables
	    }
	}
	foreach vb $fvbl {
	    eval $action $sh {$vb}
	}
	if { ! $eov } {
	    $sh getbulk 0 $reps $himatch \
		[concat processBulk "%S" {"%V"} "%E" \
		     $start_oid $reps $action $args]
	} else {
	    set eov_handler [lindex $args 0]
	    if { $eov_handler != "" } {
		eval $eov_handler $sh
	    }
	}
    } else {
	set ehandler [lindex $args 1]
	if { $ehandler != "" } {
	    eval $ehandler $sh $err
	}
    }
}

proc bulkWalk { sh var reps action args } {

    set start_oid [mib oid $var]
    $sh getbulk 0 $reps $start_oid \
	[concat processBulk "%S" {"%V"} "%E" \
	     $start_oid $reps $action $args]
    return
}
