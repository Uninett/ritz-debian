#
# $Id$
#

VERSION=0.3a

SUBDIR=emt ritz sha tpoller traffic vwatch zino

all: version.tcl subst

version.tcl: Makefile
	rm -f version.tcl
	echo "set Version \"${VERSION}\"" > version.tcl

subst: Makefile.inc Makefile mk-subst.awk
	rm -f subst.new
	awk -f mk-subst.awk Makefile.inc > subst.new
	@if [ -f ${.CURDIR}/subst ]; then \
		if cmp -s ${.CURDIR}/subst subst.new; then \
			: equal, so no need to update; \
			rm -f subst.new; \
		else \
			echo mv subst.new ${.CURDIR}/subst; \
			mv subst.new ${.CURDIR}/subst; \
		fi \
	else \
		echo mv subst.new ${.CURDIR}/subst; \
		mv subst.new ${.CURDIR}/subst; \
	fi


install clean:

dist:

.include <bsd.subdir.mk>
.include <bsd.prog.mk>
