#
# $Id$
#

catch { namespace delete ::util }

namespace eval ::util {
    namespace export copyArray mtoms

    proc copyArray { from to } {
	upvar $from From
	upvar $to To

	catch { unset To }
	foreach ix [array names From] {
	    set To($ix) $From($ix)
	}
    }

    proc mtoms { mins } {

	return [expr int( $mins * 60 * 1000 )]
    }

}
