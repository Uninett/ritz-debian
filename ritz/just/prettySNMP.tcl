package provide prettySNMP 0.0

catch { namespace delete ::prettySNMP }

namespace eval ::prettySNMP {
    namespace export prettyIfDescr prettyIfType prettyIfAs prettyIfOs
    namespace export prettyIfSpeed prettyMTU prettyLongTime
    #
    # Some pretty-printing functions
    #
    proc prettyIfDescr { desc } {
	if { "$desc" == "" } {
	    return "none"
	}
	regsub "FastEthernet" $desc "FaEth" desc
	regsub "Ethernet" $desc "Ether" desc
	regsub -- "-B-Channel-" $desc "-B-Ch-" desc
	regsub -- " layer$" $desc "" desc
	regsub -all " " $desc - desc
	return $desc
    }
    #
    # Shorten some interface type strings
    # Convert common numeric values into strings
    # Shorten some really long strings to shorter versions
    #
    proc prettyIfType { type } {
	switch -exact $type {
	    ethernet-csmacd { return "ether" }
	    propPointToPointSerial { return "prop-ser" }
	    softwareLoopback { return "loopback" }
	    rfc877-x25 { return "x25" }
	    frame-relay { return "frame-rel" }
	    37 { return "atm" }
	    39 { return "sonet" }
	    46 { return "hssi" }
	    49 { return "aal5" }
	}
	return $type
    }

    #
    # Translate up/down into on/off
    #
    proc prettyIfAs { as } {
	switch -exact $as {
	    up { return "on" }
	    down { return "off" }
	}
	return $as
    }

    proc prettyIfOs { os } {
	switch -exact $os {
	    testing { return "test" }
	    4       { return "unkn" }
	    5       { return "dorm" }
	}
	return $os
    }

    #
    # Print interface speeds in a more friendly format, especially for high
    # speed interfaces.
    #
    proc prettyIfSpeed { speed } {
	if { $speed < 0 } {
	    return "neg?"
	} 
#	if { [expr [flagSet k] || [flagSet n]] } {
#	    return [format "%u" [expr int($speed / 1000.0)]]
#	}
	if { $speed >= 1000000.0 } {
	    return [format "%4.3gM" [expr $speed / 1000000.0]]
	} elseif { $speed >= 1000.0 } {
	    return [format "%4.3gk" [expr $speed / 1000.0 ]]
	} elseif { $speed < 0.001 } {
	    return "0 "
	} else {
	    return [format "%4.3g " $speed]
	}
    }

    proc prettyMTU { m } {
	if { "$m" == "" } {
	    return "none"
	} else {
	    return $m
	}
    }

    proc prettyLongTime { t } {
	set res ""
	set done 0

	if { ![info exists t] } { return 0 }
	if { $t > 604800 } {
	    set done 1
	    append res [expr $t / 604800]w
	    set t [expr $t % 604800]
	}
	if { [expr ( $t > 86400 ) || $done] } {
	    append res [expr $t / 86400]d
	    if { $done } { return $res }
	    set res [set res]
	    set done 1
	    set t [expr $t % 86400]
	}
	if { [expr ($t > 3600) || $done] } {
	    append res [expr $t / 3600]
	    if { $done } { return $res }
	    set res [set res]h
	    set done 1
	    set t [expr $t % 3600]
	}
	if { [expr ($t > 60) || $done] } {
	    append res [expr $t / 60]
	    if { $done } { return $res }
	    set res [set res]:
	    set done 1
	    set t [expr $t % 60]
	}
	if { !$done } {
	    set res 0:
	}
	append res [format "%02d" $t]
	return $res
    }
}
