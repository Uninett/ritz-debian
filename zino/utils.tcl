#
# $Id$
#

proc max { args } {
    foreach a $args {
	if { [info exists max] } {
	    if { $a > $max } { set max $a }
	} else { set max $a }
    }
    return $max
}

proc min { args } {
    foreach a $args {
	if { [info exists min] } {
	    if { $a < $min } { set min $a }
	} else { set min $a }
    }
    return $min
}

proc ucFirst { s } {
    set c [string index $s 0]
    set s2 [string range $s 1 end]
    return [format "%s%s" [string toupper $c] $s2]
}
