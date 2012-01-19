#
# Minimal SNMP agent implementing "how long have we been running".
#

mib load ../mibs/UNINETT-SMI.my
mib load ../mibs/UNINETT-ZINO-MIB.my

proc initAgent { } {
    global agent

    set si [interp create -safe]

    $si eval set startTime [clock seconds]
    $si eval set zinoUpTime 0

    set agent [snmp session -agent $si -version SNMPv2c -port 8000]

    $agent instance zinoUpTime.0 zinoUpTime
    $agent bind zinoUpTime.0 get {
	set zinoUpTime [expr [clock seconds] - $startTime]
    }
}
