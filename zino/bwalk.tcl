#
# $Id$
#

#
# Set of functions to do a single-variable GET-BULK with the given
# number of repetitions, with optional end-of-varlist and error handlers.
#

proc processBulk { sh vbl err start_oids reps action args } {

    if { $err == "noError" } {
	set eov 0
	set fvbl {};		# filtered variable binding list
	set n 0
	set numvar [llength $start_oids]
	foreach vl $vbl {
	    foreach vb $vl {
	        set match 0
	        set oid [lindex $vb 0]
	        set soid [lindex $start_oids [expr $n % $numvar]]
	        if [oidPfxMatch $soid $oid] {
		    set himatch($soid) $oid
		    lappend fvbl $vb
		    set match 1
	        }
	        set n [expr $n + 1]
	        if { ! $match } {
		    set eov 1;	# end of matching variables
	        }
	    }
	}

	# process filtered/matching list of variable bindings
	# pass as many variable bindings per round as we were given
	while { $fvbl != {} } {
	    set vbl {}
	    foreach v $start_oids { # just step through them, counting
		lappend vbl [lindex $fvbl 0]
		set fvbl [lrange $fvbl 1 end]; # pop off head
	    }
	    eval $action $sh {$vbl}
	}

	if { ! $eov } {
	    set newvars {}
	    foreach v $start_oids {
		lappend newvars $himatch($v)
	    }
	    $sh getbulk 0 $reps $newvars \
		[concat processBulk "%S" {{"%V"}} "%E" \
		     [list $start_oids] $reps $action $args]
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

proc bulkWalk { sh vars reps action args } {

    set oidl {}
    foreach v $vars {
	set oid [mib oid $v]
	lappend oidl $oid
    }

    $sh getbulk 0 $reps $oidl \
	[concat processBulk "%S" {{"%V"}} "%E" \
	     [list $oidl] $reps $action $args]
    return
}
