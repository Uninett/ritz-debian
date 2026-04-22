# Copyright (c) 1998, 1999
#      UNINETT.  All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#      This product includes software developed by UNINETT.
# 4. Neither the name of UNINETT nor the names
#    of its contributors may be used to endorse or promote
#    products derived from this software without specific prior
#    written permission.
# 
# THIS SOFTWARE IS PROVIDED BY UNINETT AND NORDUnet ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL UNINETT OR NORDUnet OR
# THEIR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# $Id$
#

catch { namespace delete ::just }

namespace eval ::just {
    namespace export sparseTableWalk asyncSparseTableWalk
    namespace export fetchTable mapNames
    namespace export vblPfxAssoc vblPfxAssosL getDNSCachedName
    namespace export getCachedServiceName

    #
    # A procedure imitating the scotty snmp walk primitive, but one
    # that will handle a sparsely populated table and still return
    # whole rows to the caller.
    #

    proc sparseTableWalk { sh varName varList body } {
	upvar $varName var
	foreach v $varList {
	    set oid [mib oid $v]
	    lappend oidList $oid
	    # Record the length of each OID for later.
	    lappend lenList [string length $oid]
	}
	
	set thisRow $oidList
	while 1 {
	    set code [catch {$sh getnext $thisRow} vblList]
	    if { $code } {
		return -code $code $vblList
	    }
	    set ixList {}
	    foreach len $lenList oid $oidList vbl $vblList {
		set v [lindex $vbl 0]
		if {[string compare $oid. [string range $v 0 $len]] == 0} {
		    lappend ixList [string range $v $len end]
		}
	    }
	    if {[llength $ixList] == 0} {
		break
	    }
	    set min [lindex [lsort -dictionary $ixList] 0]
	    set thisRow {}
	    set myvar {}
	    foreach oid $oidList vbl $vblList {
		set v [lindex $vbl 0]
		append oid $min
		if {[string compare $oid $v] == 0} {
		    lappend myvar $vbl
		} else {
		    lappend myvar {{} {} {}}
		}
		lappend thisRow $oid
	    }
	    set var $myvar
	    uplevel $body
	}
    }

    #
    # An asyncronous version of the above.
    #
    # Note that body, endscript (if given) and errscript (if given)
    # will all be evaluated in a procedure context of their own (but
    # in this (i.e. ::just) namespace, and not in the stack context of
    # the original caller of asyncSparseTableWalk, the reason being
    # that the SNMP callback scripts are called from the global
    # context, so the callers context is no longer available.
    # Therefore, do substitution of "%S" and "%E" on the callback
    # scripts before they are evaluated, to give some hooks back to
    # these scripts.
    #

    proc asyncSparseTableWalk {
	sh varName varList body { endscript "" } { errscript "" }
    } {

	foreach v $varList {
	    set oid [mib oid $v]
	    lappend oidList $oid
	    # Record the length of each OID for later.
	    lappend lenList [string length $oid]
	}
	
	$sh getnext $oidList [list \
		::just::processRow "%S" "%E" {{%V}} \
		$oidList $oidList $lenList \
		$varName $body $endscript $errscript]
	return
    }

    # set up a new empty stack context
    proc doBody { varname vbl body } {
	set $varname $vbl
	unset vbl
	eval $body
    }

    # set up a new empty stack context
    proc doScript { body } {
	eval $body
    }

    # The async callback handler
    proc processRow {
	sh err vblList thisRow oidList lenList \
		varName body endscript errscript
    } {

	if { $err != "noError" } {
	    if { $errscript != "" } {
		# Simulate callback substitution for what we have
		regsub -all "%E" $errscript "$err" errscript
		regsub -all "%S" $errscript "$sh" errscript
		doScript $errscript
		return
	    } else {
		error $err;
	    }
	}

	set ixlist {}

	# Unpack one level of list nesting
	eval set upl $vblList

	foreach len $lenList oid $oidList vbl $upl {
	    set v [lindex $vbl 0]
            if {$len == ""} {
                set len 0; # Workaround for when lenList is too short...
            }
	    if {[string compare $oid. [string range $v 0 $len]] == 0} {
		lappend ixList [string range $v $len end]
	    }
	}
	if {! [info exists ixList]} {
	    if { $endscript != "" } {
		# Do callback substitution for what we have
		regsub -all "%E" $endscript "$err" endscript
		regsub -all "%S" $endscript "$sh" endscript
		doScript $endscript
	    }
	    return; # end of table
	}

	set min [lindex [lsort -dictionary $ixList] 0]
	set thisRow {}
	set myvarlist {}
	foreach oid $oidList vbl $upl {
	    set v [lindex $vbl 0]
	    append oid $min
	    if {[string compare $oid $v] == 0} {
		lappend myvarlist $vbl
	    } else {
		lappend myvarlist {{} {} {}}
	    }
	    lappend thisRow $oid
	}

	doBody $varName $myvarlist $body

	$sh getnext $thisRow [list \
		::just::processRow "%S" "%E" {{%V}} \
		$thisRow $oidList $lenList \
		$varName $body $endscript $errscript]
    }

    #
    # Fetch an SNMP table, synchronously and with one variable at a
    # time.  Stash the retrieved variables into the specified array
    # and return the sorted list of indexes to the caller.
    # Use the (stripped) index and the variable name given by the
    # caller (either a symbolic name or an OID) as the second part of
    # the array key, separated with a comma.
    #
    proc fetchTable { sh tabName varList } {
	upvar $tabName tab
	
	foreach var $varList {
	    set oid [mib oid $var]
	    set len [string length $oid]
	    incr len
	    set code [catch \
		    {
		$sh walk x $oid {
		    set car [lindex $x 0]
		    set roid [lindex $car 0]
		    set ix [string range $roid $len end]
		    set tab($ix,$var) [lindex $car 2]
		    set ixtab($ix) 1
		}
	    } err]
	}
	return [lsort -dictionary [array names ixtab]]
    }

    proc mapNames { l } {
	foreach v $l {
	    lappend res [mib oid $v]
	}
	return $res
    }

    #
    # Lisp-like assoc function.  Look up a prefix OID in a varBind list.
    # Returns the value of the corresponding variable.
    #
    proc vblPfxAssoc { oid vbl } {
	set ix [lsearch $vbl $oid.*]
	if {$ix == -1} {
	    return ""
	} else {
	    return [lindex [lindex $vbl $ix] 2]
	}
    }

    proc vblPfxAssocL { oid vbl } {
	set ix [lsearch $vbl $oid.*]
	if {$ix == -1} {
	    return {{} {} {}}
	} else {
	    return [lindex $vbl $ix]
	}
    }


    variable ptrCache
    variable serviceCache

    #
    # Don't do a DNS lookup for every IP-address.  Use a private cache.
    #

    proc getDNSCachedName { ipAddr } {
	variable ptrCache
	if { ![info exists ptrCache($ipAddr)] } {
	    if { [catch { dns name $ipAddr } name] } {
		set ptrCache($ipAddr) $ipAddr
	    } else {
		set ptrCache($ipAddr) $name
	    }
	}
	return $ptrCache($ipAddr)
    }

    #
    # Ditto for services
    #
    proc getCachedServiceName { service proto } {
	variable serviceCache
	if { ![info exists serviceCache($service,$proto)] } {
	    if { [catch {netdb services name $service $proto} name] } {
		set serviceCache($service,$proto) $service
	    } else {
		set serviceCache($service,$proto) $name
	    }
	}
	return $serviceCache($service,$proto)
    }
}

package provide justSNMP 0.1
