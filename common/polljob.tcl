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
# Will by default do upcalls to ::initDev, ::pollDev, and
# ::destroyDev, these upcalls can be modified with ::polljob::init.
# These are all called with an snmp handle as the single argument.
#
# Provides
#      handle $devname
#      name $handle
# commands for translation between device name and snmp handle.
#

catch { namespace delete ::polljob }

namespace eval ::polljob {
    namespace export start restart stop init
    namespace export name handle

    namespace import ::util::mtoms

    variable cx

    variable initDev ::initDev
    variable pollDev ::pollDev
    variable destroyDev ::destroyDev


    proc name { sh } {
	variable cx
	return $cx($sh,name)
    }

    proc handle { dev } {
	variable cx
	return $cx($dev,handle)
    }

    # spread poll scheduling of devices over default interval

    proc spreadIntv { devs } {

	set ndevs [llength $devs]
	if { $ndevs == 0 } { return 0; }

	set intv [::config::defaults interval]
	return [expr ( $intv + 0.0 ) / $ndevs]
    }

    proc snmpVersion { dev } {

	if { [::config::conf $dev hcounters] != "no" } {
	    return "SNMPv2c"
	}
	return "SNMPv1"
    }

    proc setup { dev } {
	variable cx

	set ip	      [::config::conf $dev address]
	set community [::config::conf $dev community]
	set intv      [::config::conf $dev interval]
	set version   [snmpVersion $dev]

	if [catch {
	    set s [snmp session \
		    -address $ip \
		    -community $community \
		    -version $version \
		    ]
	} msg] {
	    puts stderr "snmp session failed for device $dev: $msg"
	    return
	}

	set cx($dev,handle) $s
	set cx($s,name) $dev
	set cx($s,interval) $intv
    }

    proc teardown { dev { upcall "" } } {
	variable cx
	
	after cancel [format "%s::startDev %s" [namespace current] $dev]

	if [info exists cx($dev,handle)] {
	    set s $cx($dev,handle)
	} else {
	    return 0
	}

	if [info exists cx($s,job)] {
	    $cx($s,job) destroy
	    unset cx($s,job)
	}

	if { $upcall != "" } {
	    $upcall $s
	}

	$s destroy
	unset cx($s,name)
	unset cx($dev,handle)
    }

    proc startCommonAfter { dev delay { upcall "" } } {
	variable cx

	setup $dev
	set s $cx($dev,handle)

	if { $upcall != "" } {
	    $upcall $s
	}

	after [mtoms $delay] \
		[format "%s::startDev %s" [namespace current] $dev]
    }

    proc startDev { dev } {
	variable cx
	variable pollDev
	
	puts [format "starting %s" $dev]

	set s $cx($dev,handle)
	set intv $cx($s,interval)
	set msintv [mtoms $intv]

	set j [job create -interval $msintv -command [list $pollDev $s]]

	unset cx($s,interval); # done with use now, no need to keep

	set cx($s,job) $j
    }

    proc startDevAfter { dev delay } {
	variable initDev

	startCommonAfter $dev $delay $initDev
    }

    proc restartDevAfter { dev delay } {

	# stop and start without upcalls
	teardown $dev
	setup $dev
	startCommonAfter $dev $delay
    }

    proc stopDev { dev } {
	variable destroyDev

	puts [format "stopping %s" $dev]
	teardown $dev $destroyDev
    }


    # Exported procedures

    proc init { init poll destroy } {
	variable initDev
	variable pollDev
	variable destroyDev

	set initDev $init
	set pollDev $poll
	set destroyDev $destroy
    }

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

	set sintv [spreadIntv $devs]
	set delta 0
	foreach d $devs {
	    restartDevAfter $d $delta
	    set delta [expr $delta + $sintv]
	}
    }

    proc stop { devs } {

#	puts [format "polljob::stop '%s'" $devs]

	foreach d $devs {
	    stopDev $d
	}
    }

}
