#
# $Id$
#
# Check status of BFD peer sessions.
#
# Initially I wanted to suppress BFD alarms if the corresponding
# physical interface is down, but that turns out to be complicated
# because Juniper doesn't implement a new enough draft of the BFD MIB
# (and Cisco barely implements it at all -- the cat45k and cat76k has
# it, but the cat65k doesn't -- go figure...)
#
# So in order to prevent the perfect becoming the enemy of good, we
# don't do that, at least not initially.
#

proc initBFD {} {

    ::persist::add ::bfdSessState
    ::persist::add ::bfdSessAddrType
    ::persist::add ::bfdSessAddr
    ::persist::add ::bfdSessDiscr
}

proc recordBFD { sh vbl } {

    set r [name $sh]

    foreach vb $vbl {
	set n [mib name [lindex $vb 0]]
	set v [lindex $vb 2]
	set ix [lindex [split $n .] 1]
	set mv [lindex [split $n .] 0]
	set var [format "%s_%s" $mv $r]
	global $var
	set [set var]($ix) $v
#	log [format "debug: setting %s(%s) to %s" $var $ix $v]
    }
}

proc formatAddr { type addr } {

    if { $type == "ipv4" } {
	set ol [split $addr ":"]
	return [format "%s.%s.%s.%s" \
		    [expr [format "0x%s" [lindex $ol 0]]] \
		    [expr [format "0x%s" [lindex $ol 1]]] \
		    [expr [format "0x%s" [lindex $ol 2]]] \
		    [expr [format "0x%s" [lindex $ol 3]]]]
    } elseif { $type == "ipv6" } {
	return $addr
    } else {
	return [format "unknown(bad type (%s))" $type]
    }
}

proc changedBFD { sh ix oldstate newstate infosource diag } {
    global bfdSessAddrType 
    global bfdSessAddr
    global bfdSessDiscr

    set r [name $sh]

    set old [eventIxExists $ix bfd]

    if { $newstate == "up" && !$old } {
	return;			# not noted, no need to note up-transition
    }
    set eid [eventId $ix bfd]

    setEventAttr $eid "router" $r
    setEventAttr $eid "polladdr" [::config::conf $r address]
    setEventAttr $eid "priority" [::config::conf $r priority]

    setEventAttr $eid "bfdState" $newstate
    
    catch {
	set addr [formatAddr $bfdSessAddrType($ix) $bfdSessAddr($ix)]
	setEventAttr $eid "bfdAddr" $addr
    }
    catch {
	set discr $bfdSessDiscr($ix)
	setEventAttr $eid "bfdDiscr" $discr
    }
    set bfdIx [lindex [split $ix ","] 1]
    setEventAttr $eid "bfdIx" $bfdIx


    set s [format "changed from %s to %s (%s)" \
	       $oldstate $newstate $infosource]
    if { $diag != "" } {
	set s [format "%s diag %s" $s $diag]
    }
    setEventAttr $eid "lastevent" $s

    if [info exists addr] {
	set s [format "%s BFD neighbor %s" $r $addr]
    } else {
	if [info exists discr] {
	    set s [format "%s BFD ix %s discr %s" $r $bfdIx $discr]
	} else {
	    set s [format "%s BFD ix %s" $r $bfdIx]
	}
    }
    set s [format "%s changed from %s to %s (%s)" \
		   $s $oldstate $newstate $infosource]

    if { $diag != "" } {
	set s [format "%s diag %s" $s $diag]
    }

    log $s
    eventLog $eid $s

    eventCommit $eid
}


proc doUpdateBFDevent { sh vbl } {

    # extract index from first var-bind
    # (vbl should only have one index value)
    set vb [lindex $vbl 0]
    set n [mib name [lindex $vb 0]]
    set ix [lindex [split $n .] 1]

    set r [name $sh]
    set gix [format "%s,%s" $r $ix]

    updateBFDevent $r $ix $gix
}

proc refreshBFDinfo { r i } {
    global bfdSessAddrType
    global bfdSessAddr
    global bfdSessDiscr

    set gix [format "%s,%s" $r $i]
#    if {[info exists bfdSessAddr($gix)] && \
#	    [info exists bfdSessDiscr($gix)]} {
#	return;			# have info, no need to fetch
#    }

    set vbl \
	[format "bfdSessDiscriminator.%d bfdSessAddrType.%d bfdSessAddr.%d" \
	     $i $i $i]
    set sh [handle $r]

    $sh get $vbl {
	if {"%E" == "noError"} {
	    recordBFD "%S" "%V"
	    doUpdateBFDevent "%S" "%V"
	} else {
	    log [format "debug: %%s: error refreshing BFD info: %%s" \
		     [name "%S"] "%E"]
	}
    }
}

proc doBFDtrap { r newstate vbl } {
    global bfdSessState

    set first 1

    foreach vb $vbl {
	set oid  [lindex $vb 0]
	set type [lindex $vb 1]
	set val  [lindex $vb 2]

	set mibvar [mib name $oid]

	set name [lindex [split $mibvar "."] 0]
	set inst [join [lrange [split $mibvar "."] 1 end] "."]

	if { $name == "bfdSessDiag" } {
	    if { $first } {
		set firstix $inst
		set first 0
	    } else {
		set lastix $inst
	    }
	    set diag [mib format "bfdSessDiag" $val]
	}
    }
    if { ! [info exists lastix] } {
	set lastix $firstix
	log [format "%s sent malformed BFD trap (only one bfdSessDiag)" $r]
    }
    if { $firstix > $lastix } {
	set tmp $lastix
	set lastix $firstix
	set firstix $tmp
    }
    for { set i $firstix } { $i <= $lastix } { set i [expr $i + 1] } {
	refreshBFDinfo $r $i
	set gix [format "%s,%d" $r $i]
	if [info exists bfdSessState($gix)] {
	    set curstate $bfdSessState($gix)
	    if { $curstate != $newstate } {
		changedBFD [handle $r] $gix $curstate $newstate "trap" $diag
	    }
	} else {
	    if { $newstate != "up" } {
		changedBFD [handle $r] $gix "unknown" $newstate "trap" $diag
	    }
	}
	set bfdSessState($gix) $newstate
    }

}

proc updateBFDevent { r ix gix } {
    global bfdSessAddrType
    global bfdSessAddr
    global bfdSessDiscr
    global bfdSessState

    if [eventIxExists $gix bfd] {
	set eid [eventId $gix bfd]

	if [catch {getEventAttr $eid "bfdAddr"}] {
	    catch {
		set addr [formatAddr $bfdSessAddrType($gix) $bfdSessAddr($gix)]
		setEventAttr $eid "bfdAddr" $addr
		set l [format "BFD neighbor %s" $addr]
		set l [format "%s is %s" $l bfdSessState($gix)]

		log $l
		eventLog $eid $l
	    }
	}
	catch {
	    set discr $bfdSessDiscr($gix)
	    setEventAttr $eid "bfdDiscr" $discr
	}
	catch {
	    setEventAttr $eid "bfdIx" $ix
	}
	eventCommit $eid
    }
}

proc endBFD { sh } {
    global bfdSessState
    global bfdSessAddrType
    global bfdSessAddr
    global bfdSessDiscr

    set r [name $sh]

    set st [format "bfdSessState_%s" $r]
    set di [format "bfdSessDiscriminator_%s" $r]
    set at [format "bfdSessAddrType_%s" $r]
    set ad [format "bfdSessAddr_%s" $r]

    global $di $st $at $ad

    foreach ix [array names [set st]] {
	set discr [set [set di]($ix)]
	set gix [format "%s,%s" $r $ix]

	set handled($ix) 1

	set bfdSessAddrType($gix) [set [set at]($ix)]
	set bfdSessAddr($gix)     [set [set ad]($ix)]
	set bfdSessDiscr($gix)    [set [set di]($ix)]

	set state [set [set st]($ix)]

	if [info exists bfdSessState($gix)] {
	    set curstate $bfdSessState($gix)
	    if { $curstate != $state } {
		changedBFD $sh $gix $curstate $state "poll" ""
	    }
	} else {
	    if { $state != "up" } {
		changedBFD $sh $gix "unknown" $state "poll" ""
	    }
	}
	set bfdSessState($gix) $state

	# If a trap came first, fill in the blanks
	updateBFDevent $r $ix $gix
    }
    foreach {ix val} [array get bfdSessState [format "%s,*" $r]] {
	if { ! [info exists handled($ix)] } {
	    array unset bfdSessState($ix)
	    array unset bfdSessAddrType($ix)
	    array unset bfdSessAddr($ix)
	    array unset bfdSessDiscr($ix)
	}
    }

    catch { unset $st }
    catch { unset $at }
    catch { unset $ad }
    catch { unset $di }
}



proc checkBFDsessions { sh } {

    bulkWalk $sh {
	bfdSessDiscriminator
	bfdSessState
	bfdSessAddrType
	bfdSessAddr
    } 20 recordBFD endBFD errBulk
}

proc checkBFD { sh } {

    $sh get "bfdAdminStatus.0" {
	# Judiciously avoid using "local" variables;
	# the callback is executed in the global context!

	if { "%E" != "noError" } {
	    # Some error happened, skip rest of polling
	    return
	}

	if { [lindex [lindex "%V" 0] 1] == "noSuchObject" } {
	    # Device doesn't do this MIB
	    return
	}
	
	if { [lindex [lindex "%V" 0] 2] != "enabled" } {
	    # BFD isn't enabled
	    return
	}

	checkBFDsessions %S
    }
}
