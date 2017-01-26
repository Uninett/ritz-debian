#
# $Id$
#

VERSION=1.0

SUBDIR=conf-diff emt mibs ritz tpoller traffic vwatch zino zinomon

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
	perl check-subst.pl -s subst -o Makefile.inc.dist

new-vars: Makefile.inc Makefile.inc.dist
	( awk -F= '/^#/{} /=/ { print $$1 }' Makefile.inc >/tmp/o.$$$$; \
	  awk -F= '/^#/{} /=/ { print $$1 }' Makefile.inc.dist >/tmp/n.$$$$; \
	  diff /tmp/o.$$$$ /tmp/n.$$$$; rm /tmp/o.$$$$ /tmp/n.$$$$ )

beforeinstall:
	@for d in ${TOPDIR} ${TOPDIR}/bin; do \
		if [ ! -d $$d ]; then \
			echo mkdir $$d; \
			mkdir $$d; \
		fi; \
	done

clean:

dist:

.include <bsd.subdir.mk>
.include <bsd.prog.mk>
.include "Makefile.inc"
