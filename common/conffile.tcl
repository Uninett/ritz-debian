#
# $Id$
#

catch { namespace delete ::conffile }

namespace eval ::conffile {
    namespace export read startCheckJob setHandler

    variable changedHandler
    variable line_number
    variable file_name

    # Read config file.
    #
    # Format is "keyword: value", neither of which can contain whitespace
    # comments from coloumn 0 starts with #
    #
    # defaults as "default keyword: value"
    #
    # individual entries (separated with blank line(s))
    # must start with "name: xxx".
    #
    # Checks attribute names against assoc array known_attrs
    # and prints warnings for "unknown" attributes if checkKnown is != 0.
    #
    # Returns list of seen object names (in "name: xxx" attribute).

    proc read { filename attrs defaults known_attrs checkKnown } {
	upvar $attrs Attrs
	upvar $defaults Defaults
	upvar $known_attrs KnownAttrs
	variable line_number
	variable file_name

	set f [open $filename]
	set line_number 0
	set file_name $filename
	set nameseen 0

	while {[gets $f line] >= 0} {
	    set line_number [expr $line_number + 1]

	    # comments, start in col 0
	    if { [regexp "^#" $line] } { continue; }
	    # objects separated by empty line(s)
	    if { [regexp "^$" $line] } {
		set nameseen 0
		continue
	    }
	    # accept only-whitespace too as "empty" line(s)
	    if { [regexp "^\[ \t\]*$" $line] } {
		set nameseen 0
		continue
	    }

	    # get attribute / value pair
	    set l [split $line]
	    set attr [lindex $l 0]
	    set val [lindex $l 1]

	    if { $attr == "default" } {
		set attr [lindex $l 1]
		set val [lindex $l 2]
		set defs 1
	    } else {
		set defs 0
	    }

	    regsub ":" $attr "" attr

	    if { $checkKnown && ! [info exists KnownAttrs($attr)]} {
		warn [format "unknown attribute: %s" $attr]
	    }

	    if { $defs } {
		set Defaults($attr) $val
	    } else {
		if { $nameseen } {
		    set Attrs($name,$attr) $val
		} else {
		    if { $attr == "name"} {
			set nameseen 1
			set name $val
			if [info exists seen($name)] {
			    warn [format \
				    "config for device %s already seen" \
				    $name]
			}
			set seen($name) 1
			lappend names $name
		    } else {
			warn [format \
				"object does not start with %s attribute" \
				{"name:"}]
		    }
		}
	    }
	}
	close $f
	return $names
    }

    proc warn { str } {
	variable file_name
	variable line_number
	
	puts stderr \
		[format \
		"conffile::read, file %s, line %d: %s" \
		$file_name $line_number $str]
    }

    # internal check job
    proc checkCfFile { name } {
	variable lastMod
	variable changedHandler
	global errorInfo

	set first 0
	file stat $name st
	if { ! [info exists lastMod] } {
	    set lastMod $st(mtime)
	    set first 1
	}
	if { $st(mtime) != $lastMod || $first } {
	    if { $first } {
		puts stderr [format \
			"Config file %s initial read starting" $name]
	    } else {
		puts stderr [format \
			"Config file %s updated, rereading" $name]
	    }
	    if [catch {$changedHandler $name} msg] {
		puts stderr [format \
			"Config handler failed: %s, retrying later" $msg]
		puts stderr $errorInfo
		return;		# Try again later
	    }
	    set lastMod $st(mtime)
	    puts stderr [format "Config file update handled OK"]
	}
    }

    # set proc to handle config file updates
    proc setHandler { h } {
	variable changedHandler

	set changedHandler $h
    }

    # name of config file, interval in seconds
    proc startCheckJob { name interval } {
	variable changedHandler

	if { ! [info exists changedHandler] } {
	    error "need to set changedHandler"
	}

	set msintv [expr $interval * 1000]
	job create \
		-interval $msintv \
		-command [list ::conffile::checkCfFile $name]
    }

}