#
# $Id
#

catch { namespace delete ::persist }

namespace eval ::persist {
    namespace export add remove
    namespace export setFile startPeriodicDump scheduleDump readDump

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

    proc setFile { file } {
	variable persistFile

	set persistFile $file
    }

    proc readDump { } {
	variable persistFile

	if { [catch { source $persistFile } msg] } {
	    error [format "Error reading %s: %s" $persistFile $msg]
	}
    }

    # intv is in minutes

    proc startPeriodicDump { intv } {
	variable persistJob

	if [info exists persistJob] {
	    catch { $persistJob destroy }
	}
	set persistJob [job create \
		-interval [expr $intv * 1000 * 60] \
		-command [namespace current]::dumpVars]
    }

    proc scheduleDump { secs } {

	after cancel dumpVars
	after [expr $secs * 1000] dumpVars
    }

    proc dumpGlobals { f } {
	variable persistVar

	foreach var [lsort [array names persistVar]] {
	    dumpGlobalVar $f $var
	}
    }

    proc dumpVars { } {
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
    # o enclose with double quotes

    proc externalize { val } {
	regsub -all "\\\\" $val "\\\\\\\\" val
	regsub -all "\"" $val "\\\"" val
	regsub -all "\n" $val "\\n" val
	return [format "\"%s\"" $val]
    }

    proc dumpGlobalVar { f var } {
	global $var

	puts $f [format "global %s" $var]
	if { [array exists $var] } {
	    foreach l_ix [lsort [array names $var]] {
		puts -nonewline $f [format "set %s(%s) " $var $l_ix]
		puts $f [externalize [set [set var]($l_ix)]]
	    }
	} else {
	    if { [info exists $var] } {
		puts -nonewline $f [format "set %s " $var]
		puts $f [externalize [set $var]]
	    } else {
		remove $var
	    }
	}
    }

    

}
