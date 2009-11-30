#
# $Id$
#

source bwalk.tcl

proc oidPfxMatch { a b } {
    append a "."
    set ix [string first $a $b]
    return [expr $ix == 0]
}

set s [snmp session -address [lindex $argv 0] -version SNMPv2c]

proc processDescr { sh vb } {

    set oid [lindex $vb 0]
    set name [mib name $oid]
    set type [lindex $vb 1]
    set val [lindex $vb 2]

    puts [format "%s %s" $name $val]
}

proc errHandler { sh err } {

    puts [format "error %s from %s" $err $sh]
}

proc endOfDescr { sh } {
    puts [format "end of descriptions from %s" $sh]
}

bulkWalk $s ifDescr 20 processDescr endOfDescr errHandler

snmp wait

exit 0
