#
# $Id$
#

VERSION=0.29

SUBDIR= cgi common db html jobs mibs plot poller report

DIRS=   ${BINDIR} ${CGIDIR} ${CONFDIR} ${HTMLDIR} ${IMGDIR} \
	${LIBDIR} ${MIBDIR} ${DBDIR} ${REPDIR} ${DATADIR} \
	${TODAYDIR} ${PLOTDIR} ${PLOTDATADIR} ${PLOTCACHE} \
	${WREPDIR} ${MREPDIR} ${MAPDIR}

# Substitution file for scripts

all: subst

subst: Makefile.inc Makefile
	rm -f subst.new
	echo "s:%BINDIR%:${BINDIR}:g" >> subst.new
	echo "s:%CACHETTL%:${CACHETTL}:g" >> subst.new
	echo "s:%CGIPFX%:${CGIPFX}:g" >> subst.new
	echo "s:%CHECKINTV%:${CHECKINTV}:g" >> subst.new
	echo "s:%CONFDIR%:${CONFDIR}:g" >> subst.new
	echo "s:%DATADIR%:${DATADIR}:g" >> subst.new
	echo "s:%DATASTART%:${DATASTART}:g" >> subst.new
	echo "s:%DATA_ROOTS%:${DATA_ROOTS}:g" >> subst.new
	echo "s:%DBDIR%:${DBDIR}:g" >> subst.new
	echo "s:%IMGDIR%:${IMGDIR}:g" >> subst.new
	echo "s:%GNUPLOT%:${GNUPLOT}:g" >> subst.new
	echo "s:%GZCAT%:${GZCAT}:g" >> subst.new
	echo "s:%GZIP%:${GZIP}:g" >> subst.new
	echo "s:%GUNZIP%:${GUNZIP}:g" >> subst.new
	echo "s:%HTMLDIR%:${HTMLDIR}:g" >> subst.new
	echo "s:%HTMLPFX%:${HTMLPFX}:g" >> subst.new
	echo "s:%LIBDIR%:${LIBDIR}:g" >> subst.new
	echo "s:%MAIL%:${MAIL}:g" >> subst.new
	echo "s:%MAPDIR%:${MAPDIR}:g" >> subst.new
	echo "s:%NOTIFY%:${NOTIFY}:g" >> subst.new
	echo "s:%PERL%:${PERL}:g" >> subst.new
	echo "s:%PING%:${PING}:g" >> subst.new
	echo "s:%PLOTCACHE%:${PLOTCACHE}:g" >> subst.new
	echo "s:%SCOTTY%:${SCOTTY}:g" >> subst.new
	echo "s:%SNMPNETSTAT%:${SNMPNETSTAT}:g" >> subst.new
	echo "s:%TOPDIR%:${TOPDIR}:g" >> subst.new
	echo "s:%WEBSRVR%:${WEBSRVR}:g" >> subst.new
	echo "s:%ZCAT%:${ZCAT}:g" >> subst.new
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

beforeinstall: subst
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

dist:
	cp Makefile.inc Makefile.inc.dist
	find . \( -name RCS -prune -o \
		  -name subst -prune -o \
		  -name Makefile.inc -o \
		  -name 'NORDstat*.tar*' -prune \) -o \
		-type f -print | tar cfzT NORDstat-${VERSION}.tar.gz -

.include "Makefile.inc"
.include <bsd.subdir.mk>
.include <bsd.prog.mk>
