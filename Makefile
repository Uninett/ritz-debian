#
# $Id$
#

VERSION=0.3a

RITZFILES=	README TODO ritz sha scotty.diff Makefile
RITZDIST=	ritz-${VERSION}.tar.gz
ZINOFILES=	README TODO zino sha mibs scotty.diff Makefile
ZINODIST=	zino-${VERSION}.tar.gz

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

dist: ${RITZDIST} ${ZINODIST}


${RITZDIST}: ${RITZFILES}
	rm -f ${RITZDIST}
	tar -cvzf ${RITZDIST} \
		--exclude RCS \
		${RITZFILES}

${ZINODIST}: ${ZINOFILES}
	rm -f ${ZINODIST}
	tar -cvzf ${ZINODIST} \
		--exclude save-state.tcl \
		--exclude secrets \
		--exclude status.err \
		--exclude save-state.save \
		--exclude routers.cf \
		--exclude eventid \
		--exclude zino.err \
		--exclude ktrace.out \
		${ZINOFILES}
