#
# $Id$
#

proc persistVar { var } {
    global persistVar

    set persistVar($var) 1
}

proc noPersistVar { var } {
    global persistVar

    catch { unset persistVar($var) }
}

proc setPersistFile { file } {
    global persistFile
    set persistFile $file
}

# Start persist-cache-dump-job,
# do every "intv" minutes

proc startPersistJob { intv } {
    global persistJob

    if { [info exists persistJob] } {
	catch { $persistJob destroy }
    }
    set persistJob [job create \
	    -interval [expr $intv * 1000 * 60] \
	    -command dumpPersistVars]
}

# Externalize a variable value, i.e.
# o substitute the two-char sequence \\ for a single backslash
# o substitute the two-char sequence \" for a single double-quote
# o substitute the two-char sequence \n for newline
# o enclose with double quotes

proc ExternalVal { val } {
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
	    puts $f [ExternalVal [set [set var]($l_ix)]]
	}
    } else {
	if { [info exists $var] } {
	    puts -nonewline $f [format "set %s " $var]
	    puts $f [ExternalVal [set $var]]
	}
    }
}


proc dumpPersistVars { } {
    global persistVar persistFile

#    puts [format "%s: %s" [getStamp] "dumping variables to $persistFile"]
    set newPersistFile [format "%s.new" $persistFile]
    set f [open $newPersistFile "w"]
    foreach var [lsort [array names persistVar]] {
	dumpGlobalVar $f $var
    }
    close $f
    exec mv -f $newPersistFile $persistFile
}

proc readPersistVars { } {
    global persistFile

    if { [catch { source $persistFile } msg] } {
	puts stderr [format "Error reading %s: %s" $persistFile $msg]
    }
}

proc schedulePersistDump { secs } {

    after cancel dumpPersistVars
    after [expr $secs * 1000] dumpPersistVars
}
