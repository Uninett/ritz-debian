#! %SCOTTY%

# $Id$

catch { source "~/.emt.tcl" }

set vl "emt_to emt_from emt_alarm_to emt_alarm_subject emt_alarm_phones"

foreach v $vl {
    if [info exists $v] {
	eval puts [format "%s=\"%s\"" $v $$v]
    }
}
exit 0
