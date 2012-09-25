#
# $Id$
#

SCRIPTS=	get-5m-perc.pl get-perc.pl re-report-day.pl report-day.pl \
		report-mon-sp.pl report-month.pl report-week.pl \
		sel-report.pl tail-stats.pl customer-ts.pl \
		ip6-day-perc.pl ip6-plot-data.pl \
		mk-customer-index.pl \
		cust-load-now.pl mk-top10.pl

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
