#
# $Id$
#

SCRIPTS=	emit-map.pl \
		ex-png.pl \
		plot-all.pl \
		intf-load.pl \
		list-ports.pl \
		load-map.pl \
		tbl-report.pl

all:

install:
	@for s in ${SCRIPTS}; do \
		base=`basename $$s .pl`; \
		dst=${CGIDIR}/$$base; \
		tmp=/tmp/rtmp.$$$$; \
		echo sed -f ../subst '<' $$s '>' $$tmp; \
		sed -f ../subst < $$s > $$tmp; \
		echo install -c -m 555 $$tmp $$dst; \
		install -c -m 555 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done

obj:
clean:
cleandir:

.include "../../Makefile.inc"
