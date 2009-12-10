#
# $Id$
#

catch { namespace delete ::persist }

namespace eval ::persist {
    namespace export setup add remove dump restore after_restore
    namespace export startPeriodicDump

    variable persistFile
    variable persistVar
    variable persistJob


    proc add { var } {
	variable persistVar

	set persistVar($var) 1
    }

    proc remove { var } {
	variable persistVar

	catch { unset persistVar($var) }
    }

    proc setup { file } {
	variable persistFile

	set persistFile $file
    }

    proc restore { } {
	variable persistFile
	variable after_handlers

	if { [catch { source $persistFile } msg] } {
	    error [format "Error reading %s: %s" $persistFile $msg]
	}
	foreach handler [array names after_handlers] {
	    catch { eval $handler }
	}
    }

    proc after_restore { handler } {
	variable after_handlers

	set after_handlers($handler) 1
    }

    proc dump { { secs 0 } } {

	after cancel [namespace current]::dumpAll
	after [expr $secs * 1000] [namespace current]::dumpAll
    }

    proc startPeriodicDump { intv } {
	variable persistJob

	if [info exists persistJob] {
	    catch { $persistJob destroy }
	}
	set persistJob [job create \
		-interval [expr $intv * 1000] \
		-command [namespace current]::dumpAll]
    }

    proc dumpGlobals { f } {
	variable persistVar

	foreach var [lsort [array names persistVar]] {
	    dumpGlobalVar $f $var
	}
    }

    proc dumpAll { } {
	variable persistFile

	set newFile [format "%s.new" $persistFile]
	set f [open $newFile "w"]
	dumpGlobals $f
	close $f
	exec mv -f $newFile $persistFile
    }
    
    # Externalize a variable value, i.e.
    # o substitute the two-char sequence \\ for a single backslash
    # o substitute the two-char sequence \" for a single double-quote
    # o substitute the two-char sequence \n for newline
    # o quote []'s, so as to avoid attempt at evaluation when sourcing
    # o enclose with double quotes

    proc externalize { val } {
	regsub -all "\\\\" $val "\\\\\\\\" val
	regsub -all "\"" $val "\\\"" val
	regsub -all "\n" $val "\\n" val
	regsub -all "\\\[" $val "\\\[" val
	regsub -all "\\\]" $val "\\\]" val
	return [format "\"%s\"" $val]
    }

    proc dumpGlobalVar { f var } {
	global $var

	set ghead [format "global %s" $var]
	if [array exists $var] {
	    puts $f $ghead
	    foreach l_ix [lsort [array names $var]] {
		puts -nonewline $f [format "set %s(%s) " $var $l_ix]
		puts $f [externalize [set [set var]($l_ix)]]
	    }
	} elseif [info exists $var] {
	    puts $f $ghead
	    puts -nonewline $f [format "set %s " $var]
	    puts $f [externalize [set $var]]
#	} else {
#	    puts "persist variable $var nonexistent"
	}
    }

}
