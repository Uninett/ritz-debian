#
# $Id$
#

proc dumpGlobals { file } {
    set f [open $file "w"]

    foreach v [lsort [info globals]] {
	global $v
	if { [array exists $v] } {
	    foreach l_ix [lsort [array names $v]] {
		puts $f [format "set %s(%s) %s" $v $l_ix [set [set v]($l_ix)]]
	    }
	} else {
	    puts $f [format "set %s %s" $v [set $v]]
	}
    }
    close $f
}
