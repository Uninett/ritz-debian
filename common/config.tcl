#
# $Id$
#

catch { namespace delete ::config }

namespace eval ::config {
    namespace export handleChangedConf conf

    namespace import ::util::copyArray
    namespace import ::polljob::start ::polljob::restart ::polljob::stop

    variable known_attrs
    variable conf
    variable defaults

    # Initialize set of well-known keywords/attributes
    set known_attrs(name) 1
    set known_attrs(address) 1
    set known_attrs(community) 1
    set known_attrs(dns) 1
    set known_attrs(interval) 1
    set known_attrs(ignorepat) 1
    set known_attrs(priority) 1
    set known_attrs(timeout) 1
    set known_attrs(retry) 1
    set known_attrs(domain) 1

    # Initialize defaults.  These are tweakable.
    set defaults(priority) 100
    set defaults(community) "public"
    set defaults(interval) 15
    set defaults(timeout) 5
    set defaults(retry) 3


    proc handleChangedConf { file } {
	variable known_attrs
	variable conf
	variable defaults

	set newdevs [conffile::read $file newconfig defaults known_attrs 1]
	fillinDefaults newconfig defaults $newdevs

	if [checkConfig newconfig $newdevs] {
	    error [format "Config file %s contains errors" $file]
	}

	if [array exists conf] {
	    set changed_devs [changedDevs conf newconfig $newdevs]
	    set removed_devs [removedDevs conf $newdevs]
	    set new_devs [newDevs conf $newdevs]
	} else {
	    set changed_devs ""
	    set removed_devs ""
	    set new_devs $newdevs
	}

	polljob::stop $removed_devs

	util::copyArray newconfig conf

	polljob::restart $changed_devs
	polljob::start $new_devs
    }

    proc fillinDefaults { newconfig defaults devs } {
	upvar $newconfig Newconfig
	upvar $defaults Defaults

	foreach defattr [array names Defaults] {
	    foreach d $devs {
		if { ! [info exists Newconfig($d,$defattr)] } {
		    set Newconfig($d,$defattr) $Defaults($defattr)
		}
	    }
	}
    }

    proc checkConfig { newconfig newdevs } {
	upvar $newconfig Newconfig

	set ret 0;		# start an optimist
	foreach d $newdevs {
	    if { ! [info exists Newconfig($d,address)] } {
		set ret 1
		puts [format "Device %d has no address specified" $d]
	    }
	}
	return $ret
    }

    proc changedDev { dev config newconfig } {
	upvar $config Config
	upvar $newconfig Newconfig

	if { ! [info exists Config($dev,address)] } {
	    return 0
	}
	foreach ix [array names Newconfig] {
	    set l [split $ix ","]
	    set d [lindex $l 0]
	    set a [lindex $l 1]
	    if { $d != $dev } { continue; }
	    if { ! [info exists Config($ix)] } { return 1; }
	    if { $Config($ix) != $Newconfig($ix) } { return 1; }
	}
	foreach ix [array names Config] {
	    set l [split $ix ","]
	    set d [lindex $l 0]
	    set a [lindex $l 1]
	    if { $d != $dev } { continue; }
	    if { ! [info exists Newconfig($ix)] } { return 1; }
	}
	return 0
    }

    proc changedDevs { config newconfig newdevs } {
	upvar $config Config
	upvar $newconfig Newconfig

	set chdevs ""
	foreach d $newdevs {
	    if [changedDev $d Config Newconfig] {
		lappend chdevs $d
	    }
	}
	return $chdevs
    }

    proc removedDevs { config newdevs } {
	upvar $config Config

	set removed ""
	foreach d $newdevs {
	    set Newdev($d) 1
	}
	foreach ix [array names Config] {
	    set l [split $ix ","]
	    set d [lindex $l 0]
	    if { ![info exists Newdev($d)] && ![info exists rmd($d)] } {
		set rmd($d) 1
		lappend removed $d
	    }
	}
	return $removed
    }

    proc newDevs { config newdevs } {
	upvar $config Config

	set new ""
	foreach d $newdevs {
	    if { ! [info exists Config($d,address)] } {
		lappend new $d
	    }
	}
	return $new
    }

    # for debugging
    proc printConf { config } {
	upvar $config Config

	foreach ix [array names Config] {
	    set l [split $ix ","]
	    set dev [lindex $l 0]

	    if { ! [info exists seen($dev)] } {
		set seen($dev) 1
		puts [format "name: %s" $dev]
		foreach ix2 [array names Config] {
		    set l [split $ix2 ","]
		    set d [lindex $l 0]
		    if { $d != $dev } { continue; }
		    set a [lindex $l 1]
		    puts [format "%s: %s" $a $Config($d,$a)]
		}
		puts ""
	    }

	}
    }

}
