#
# $Id$
#

PSRCS=	cur-vers.pl \
	vw-daily.pl \
	vw-day-report.pl \
	vw-month-rst.pl \
	vw-month-upgr.pl

INCSRCS=../common/util.tcl \
	../common/conffile.tcl \
	../common/polljob.tcl \
	../common/config.tcl

TSRCS=	vwatch.tcl \
	vwatch-head.tcl \
	vwatch-main.tcl

SRCS=	${PSRCS} ${TSRCS} start-vwatch.sh

COMMON=	pretty-ios.pl \
	unctime.pl

PPROGS=	cur-vers \
	vw-daily \
	vw-day-report \
	vw-month-rst \
	vw-month-upgr

TPROGS=	vwatch

PROGS=	${PPROGS} ${TPROGS} start-vwatch

SUBST=	${.CURDIR}/../subst

all: ${PROGS}

start-vwatch: start-vwatch.sh ${SUBST}
	rm -f $@
	sed -f ${SUBST} $@.sh > $@

${PPROGS}: ${PSRCS} ${SUBST}
	@for f in ${PSRCS}; do \
		b=`basename $$f .pl`; \
		echo rm -f $$b; \
		rm -f $$b; \
		echo sed -f ${SUBST} ${.CURDIR}/$$f '>' $$b; \
		sed -f ${SUBST} ${.CURDIR}/$$f > $$b; \
	done

vwatch: vwatch.tcl vwatch-main.tcl ${SUBST} Makefile
	rm -f vwatch
	(sed -f ${SUBST} ${.CURDIR}/vwatch-head.tcl; \
	cat ${INCSRCS}; \
	cat ${.CURDIR}/vwatch.tcl; \
	sed -f ${SUBST} ${.CURDIR}/vwatch-main.tcl) > vwatch

install: ${PROGS} ${COMMON}
	@for f in ${PROGS}; do \
		echo install -c -m 555 $$f ${BINDIR}; \
		install -c -m 555 $$f ${BINDIR}; \
	done
	@for f in ${COMMON}; do \
		echo install -c -m 444 $$f ${LIBDIR}; \
		install -c -m 444 $$f ${LIBDIR}; \
	done
	@if [ ! -d ${TOPDIR}/ver-watch/logs/today/descs ]; then \
		echo mkdir -p ${TOPDIR}/ver-watch/logs/today/descs; \
		mkdir -p ${TOPDIR}/ver-watch/logs/today/descs; \
	fi
	install -c -m 555 start-vwatch ${BINDIR}

clean:
	rm -f ${PROGS}

.include "../Makefile.inc"
.include <bsd.prog.mk>
