#
# $Id$
#

package require Tnm
package require Tix

mib load rfc1213.mib

namespace import ::mib2util::netstat


proc main { } {
    global allCases filteredCases sortedCases
    global Authenticated
    global Server Port
    global AllowClearTextAuth

    global Secret User Server Port
    global _Secret _User _Server _Port

    if { [file exists ~/.smon.tcl] } {
	source ~/.smon.tcl
    }
    if { [file exists ~/.ritz.tcl] } {
	source ~/.ritz.tcl
    }

    if { ![info exists AllowClearTextAuth] } {
	# the most secure setting
	set AllowClearTextAuth 0
    }

    set sortedCases {}
    set allCases {}
    set filteredCases {}

    initUi
    if { [info exists Server] && [info exists Port] } {
	uiOpenServer
    }

    uiDisplaySummary $sortedCases
}
