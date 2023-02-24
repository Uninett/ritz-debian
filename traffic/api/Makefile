#
# $Id$
#

LIBS=		traffic_sum.pm

API_SCRIPTS=	rest_api.pl \
		rest_api.psgi

LIBDIR=		${TOPDIR}/lib
APIDIR=		${TOPDIR}/api

SUBST=		${.CURDIR}/../../subst


all:

install:
	mkdir -p ${LIBDIR}
	@for s in ${LIBS}; do \
		dst=${LIBDIR}/$$s; \
		tmp=/tmp/rtmp.$$$$; \
		echo sed -f ${SUBST} '<' $$s '>' $$tmp; \
		sed -f ${SUBST} < $$s > $$tmp; \
		echo install -c -m 555 $$tmp $$dst; \
		install -c -m 555 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done

	mkdir -p ${APIDIR}
	@for s in ${API_SCRIPTS}; do \
		dst=${APIDIR}/$$s; \
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
