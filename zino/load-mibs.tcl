#
# $Id$
#

#
# This is _really_ ugly.  Ensure that rfc2863.mib is loaded prior to
# rfc1213.mib, and likewise ensure that IANAifType.tc is loaded as early as
# possible.
#
set x [lsearch -exact $tnm(mibs:core) rfc1213.mib]
if { $x >= 0 } {
    set tnm(mibs:core) [linsert $tnm(mibs:core) $x rfc2863.mib]
}

set x [lsearch -exact $tnm(mibs:core) compat.tc]
if { $x >= 0 } {
    set tnm(mibs:core) [lreplace $tnm(mibs:core) $x $x compat.tc IANAifType.tc]
}

mib load ../mibs/IANAifType.tc
mib load ../mibs/CISCO-SMI.my
mib load ../mibs/CISCO-CONFIG-MAN-MIB.my
mib load ../mibs/CISCO-PRODUCTS-MIB.my
mib load ../mibs/OLD-CISCO-INTERFACES-MIB.my
mib load ../mibs/OLD-CISCO-TCP-MIB.my
mib load ../mibs/OLD-CISCO-TS-MIB.my
mib load ../mibs/INET-ADDRESS-MIB.my
mib load ../mibs/CISCO-VTP-MIB.my
mib load ../mibs/CISCO-PIM-MIB.my
mib load ../mibs/CISCO-BGP4-MIB.my
mib load ../mibs/CISCO-IETF-BFD-MIB.my
mib load ../mibs/MSDP-MIB.my
mib load ../mibs/BGP4-MIB.my
mib load ../mibs/CISCO-MAC-NOTIFICATION-MIB.my
mib load ../mibs/PIM-MIB.my
mib load ../mibs/CISCO-ENVMON-MIB.my
mib load ../mibs/BRIDGE-MIB.my
mib load ../mibs/ENTITY-MIB.my
mib load ../mibs/mib.traps
mib load ../mibs/cisco-10-mib.my
mib load ../mibs/mib-jnx-smi.txt
mib load ../mibs/mib-jnx-chassis-alarm.txt
mib load ../mibs/mib-jnx-exp.txt
mib load ../mibs/mib-jnx-bfd-exp-mod.txt
mib load rfc1213.mib
mib load rfc1573.mib
mib load rfc1907.mib
mib load ../mibs/mib-rfc3289.txt
mib load ../mibs/mib-rfc3811.txt
mib load ../mibs/mib-rfc3812.txt
mib load ../mibs/mib-jnx-mpls.txt
