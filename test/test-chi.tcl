#!/store/bin/scotty

#
# $Id$
#

# Simple routines/settings to test sparse-walk
# of the NORDUnet/Chicago router where ATM subinterfaces
# now has appeared, something which has broken the table
# walk in the agent.  (Sigh!)

set vl [list "ifInOctets" "ifInUcastPkts" \
	"ifInNUcastPkts" "ifInDiscards" \
	"ifInErrors" "ifOutOctets" \
	"ifOutUcastPkts" "ifOutNUcastPkts" \
	"ifOutDiscards" "ifOutErrors"]
#lappend vl "locIfInRunts" "locIfInGiants" \
#	"locIfInCRC" "locIfInFrame" \
#	"locIfInOverrun" "locIfInIgnored" \
#	"locIfInAbort" "locIfResets" \
#	"locIfRestarts" "locIfCollisions"

lappend vl "ifDescr"

proc printRes { vbl } {

    foreach vb $vbl {
	set oid [lindex $vb 0]
	if { $oid == {} } { continue; }
	set name [mib name $oid]
	set val [lindex $vb 2]
	puts [format "%s: %s" $name $val]
    }
}

set vl14 {}
foreach v $vl {
    lappend vl14 [format "%s.14" $v]
}
