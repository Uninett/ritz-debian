#
# $Id$
#

SCRIPTS=	re-report-day.pl report-day.pl \
		report-mon-sp.pl report-month.pl report-week.pl \
		sel-report.pl

SUBST=	${.CURDIR}/../../subst

all:

install:
	@for s in ${SCRIPTS}; do \
		base=`basename $$s .pl`; \
		dst=${BINDIR}/$$base; \
		tmp=/tmp/rtmp.$$$$; \
		echo sed -f ${SUBST} '<' $$s '>' $$tmp; \
		sed -f ${SUBST} < $$s > $$tmp; \
		echo install -c -m 555 $$tmp $$dst; \
		install -c -m 555 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done

obj:
clean:
cleandir:

.include "../../Makefile.inc"
