#
# $Id$
#

catch { namespace delete ::util }

namespace eval ::util {
    namespace export copyArray

    proc copyArray { from to } {
	upvar $from From
	upvar $to To

	unset To
	foreach ix [array names From] {
	    set To($ix) $From($ix)
	}
    }

}
