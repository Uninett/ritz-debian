#
# $Id$
#

VERSION=0.2f

RITZFILES=	README TODO ritz sha scotty.diff Makefile
RITZDIST=	ritz-${VERSION}.tar.gz
ZINOFILES=	README TODO zino sha mibs scotty.diff Makefile
ZINODIST=	zino-${VERSION}.tar.gz

all install clean:

dist: ${RITZDIST} ${ZINODIST}


${RITZDIST}: ${RITZFILES}
	rm -f ${RITZDIST}
	tar -cvzf ${RITZDIST} \
		--exclude RCS \
		${RITZFILES}

${ZINODIST}: ${ZINOFILES}
	rm -f ${ZINODIST}
	tar -cvzf ${ZINODIST} \
		--exclude RCS \
		--exclude save-state.tcl \
		--exclude secrets \
		--exclude status.err \
		--exclude save-state.save \
		--exclude routers.cf \
		--exclude eventid \
		--exclude zino.err \
		--exclude ktrace.out \
		${ZINOFILES}
