#
# $Id$
#

# Test asynchronous sparse-walk routines, compare
# to synchronous version

source "../common/swalk.tcl"

namespace import ::just::*

set s [snmp session -address trdS-gw.uninett.no]

proc eHandler { sh err } {

    puts [format "%s: %s" $sh $err]
}

setSparseWalkEHandler ::eHandler

proc doAsTest {} {
    global s

    sparseTableWalk $s x \
	    "ifDescr ifType ifSpeed ifAdminStatus ifOperStatus" {
	set desc [lindex [lindex $x 0] 2]
	set type [lindex [lindex $x 1] 2]
	set spd  [lindex [lindex $x 2] 2]
	set adm  [lindex [lindex $x 3] 2]
	set ops  [lindex [lindex $x 4] 2]
	puts [format "%s %s %s %s %s" $desc $type $spd $adm $ops]
    } {
	set done 1
    }
    vwait done
}

proc doSyTest {} {
    global s

    set ixes [fetchTable $s table \
	    "ifDescr ifType ifSpeed ifAdminStatus ifOperStatus"]
    foreach ix $ixes {
	puts [format "%s %s %s %s %s" \
		$table($ix,ifDescr) \
		$table($ix,ifType) \
		$table($ix,ifSpeed) \
		$table($ix,ifAdminStatus) \
		$table($ix,ifOperStatus)]
    }
}

# 0 iterations:
# 1.418u 0.459s 0:01.90 97.8% 0+0k 0+24io 15pf+0w

#puts [time doAsTest 100]
# 10 iterations:
# 3.602u 0.564s 0:04.77 87.2% 0+0k 0+24io 15pf+0w
# 100 iterations:
# 22.257u 2.471s 0:32.90 75.1% 0+0k 0+23io 15pf+0w

#puts [time doSyTest 100]
# 10 iterations:
# 4.294u 0.642s 0:23.39 21.0% 0+0k 67+24io 15pf+0w
# 100 iterations:
# 26.375u 5.570s 0:59.96 53.2% 0+0k 0+24io 15pf+0w

# So... the "parallel sparse table walk" is more efficient than the
# "synchronous table walk fetching one variable at a time" operation.


# Needed to have the script terminate:
$s destroy
