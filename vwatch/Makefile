#
# $Id$
#

PSRCS=	cur-vers.pl \
	vw-daily.pl \
	vw-day-report.pl \
	vw-month-rst.pl \
	vw-month-upgr.pl

TSRCS=	vwatch.tcl \
	vwatch-head.tcl \
	vwatch-main.tcl

SRCS=	${PSRCS} ${TSRCS}

COMMON=	pretty-ios.pl \
	unctime.pl

PPROGS=	cur-vers \
	vw-daily \
	vw-day-report \
	vw-month-rst \
	vw-month-upgr

TPROGS=	vwatch

PROGS=	${PPROGS} ${TPROGS}

all: ${PROGS}

${PPROGS}: ${PSRCS} ../subst
	@for f in ${PSRCS}; do \
		b=`basename $$f .pl`; \
		echo rm -f $$b; \
		rm -f $$b; \
		echo sed -f ../subst $$f '>' $$b; \
		sed -f ../subst $$f > $$b; \
	done

vwatch: vwatch.tcl vwatch-main.tcl ../subst
	rm -f vwatch
	(sed -f ../subst vwatch-head.tcl; \
	cat vwatch.tcl; \
	sed -f ../subst vwatch-main.tcl) > vwatch

install: ${PROGS} ${COMMON}
	@for f in ${PROGS}; do \
		echo install -c -m 555 $$f ${BINDIR}; \
		install -c -m 555 $$f ${BINDIR}; \
	done
	@for f in ${COMMON}; do \
		echo install -c -m 444 $$f ${LIBDIR}; \
		install -c -m 444 $$f ${LIBDIR}; \
	done
	if [ ! -d ${TOPDIR}/ver-watch/logs/today/descs ]; then \
		echo mkdir -p ${TOPDIR}/ver-watch/logs/today/descs; \
		mkdir -p ${TOPDIR}/ver-watch/logs/today/descs; \
	fi

clean:
	rm -f ${PROGS}

.include "../Makefile.inc"

