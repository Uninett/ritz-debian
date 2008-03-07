#
# $Id$
#

SCRIPTS=date.pl newtimelocal.pl plot.pl read-5m-sum.pl read-day-report.pl \
	read-hr-log.pl read-raw-log.pl read-week-report.pl \
	scaling.pl search.pl timelocal.pl tmpfiles.pl utils.pl \
	conn-common.pl

SUBST=	${.CURDIR}/../../subst

all:

install:
	@for s in ${SCRIPTS}; do \
		dst=${LIBDIR}/$$s; \
		tmp=/tmp/comtmp.$$$$; \
		echo sed -f ${SUBST} '<' $$s '>' $$tmp; \
		sed -f ${SUBST} < $$s > $$tmp; \
		echo install -c -m 444 $$tmp $$dst; \
		install -c -m 444 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done

obj:
clean:
cleandir:

.include "../../Makefile.inc"
