#
# $Id$
#

#
# Interfaces to outside:
#
# Uses ::config::defaults and
#      ::config::conf
# (which cannot be imported due to circular dependency)
#
# Assumes global procedures
#      initDev $s
#      pollDev $s
#      destroyDev $s
# where $s is "snmp handle".
#
# Also provides
#      cx($devname,handle)
#      cx($handle,name)
# for translation between device name and snmp handle.
#

catch { namespace delete ::polljob }

namespace eval ::polljob {
    namespace export start restart stop cx
    namespace import ::util::mtoms

    variable cx

    proc spreadIntv { devs } {
	variable ::config::defaults

	set ndevs [llength $devs]
	if { $ndevs == 0 } { return 0; }

	set intv $::config::defaults(interval)
	return [expr ( $intv + 0.0 ) / $ndevs]
    }

    proc startDevAfter { dev delay } {
	variable ::config::conf
	variable cx

	set ip $::config::conf($dev,address)
	set community $::config::conf($dev,community)
	set intv $::config::conf($dev,interval)

	set code [catch {snmp session -address $ip -community $community} s]
	if $code {
	    err "snmp session failed for device $dev: $s"
	    return
	}

	set cx($dev,handle) $s
	set cx($s,name) $dev
	set cx($s,interval) $intv

	::initDev $s

	after [mtoms $delay] "::polljob::startDev $dev"
    }

    proc startDev { dev } {
	variable cx
	
	set s $cx($dev,handle)
	set intv $cx($s,interval)
	set msintv [mtoms $intv]

	set j [job create -interval $msintv -command [list ::pollDev $s]]

	unset cx($s,interval); # done with use now

	set cx($s,job) $j
    }

    proc stopDev { dev } {
	variable cx
	
	after cancel "::polljob::startDev $dev"

	if [info exists cx($dev,handle)] {
	    set s $cx($dev,handle)
	}

	if [info exists cx($s,job)] {
	    $cx($s,job) destroy
	    unset cx($s,job)
	}

	::destroyDev $s

	$s destroy
	unset cx($s,name)
	unset cx($dev,handle)
    }


    # Exported procedures

    proc start { devs } {

#	puts [format "polljob::start '%s'" $devs]

	set sintv [spreadIntv $devs]
	set delta 0
	foreach d $devs {
	    startDevAfter $d $delta
	    set delta [expr $delta + $sintv]
	}
    }

    proc restart { devs } {

#	puts [format "polljob::restart '%s'" $devs]

	stop $devs
	start $devs
    }

    proc stop { devs } {

#	puts [format "polljob::stop '%s'" $devs]

	foreach d $devs {
	    stopDev $d
	}
    }

}
