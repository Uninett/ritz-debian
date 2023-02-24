#
# $Id$
#

VERSION=0.29

SUBDIR= api cgi common db html jobs mibs plot report

DIRS=   ${BINDIR} ${CGIDIR} ${CONFDIR} ${HTMLDIR} ${IMGDIR} \
	${LIBDIR} ${MIBDIR} ${DBDIR} ${REPDIR} ${DATADIR} \
	${DATADIR}/tail-save ${BACKUPDIR} \
	${TODAYDIR} ${PLOTDIR} ${PLOTDATADIR} ${PLOTCACHE} \
	${WREPDIR} ${MREPDIR} ${MAPDIR}

# Substitution file for scripts

beforeinstall:
	@for d in ${DIRS}; do \
		if [ ! -d $$d ]; then \
			echo mkdir $$d; \
			mkdir $$d; \
		fi \
	done
	chmod 777 ${IMGDIR} ${PLOTCACHE}

count:
	find . \( -name RCS -prune -o \
		  -name mibs -prune -o \
		  -name '*.fig' -prune -o \
		  -name '*.ps' -prune \) -o \
		-type f -print | xargs file | egrep text | \
	awk -F: '{ print $$1 }' | xargs wc -l

.include "../Makefile.inc"
.include <bsd.subdir.mk>
.include <bsd.prog.mk>
