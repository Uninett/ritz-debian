#
# $Id$
#

CONFS=		config.tcl

SCRIPTS=	poller.tcl

all:

install:
	@for s in ${SCRIPTS}; do \
		dst=${BINDIR}/`basename $$s .tcl`; \
		tmp=/tmp/jtmp.$$$$; \
		echo sed -f ../subst '<' $$s '>' $$tmp; \
		sed -f ../subst < $$s > $$tmp; \
		echo install -c -m 555 $$tmp $$dst; \
		install -c -m 555 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done
	@for s in ${CONFS}; do \
		dst=${CONFDIR}/$$s; \
		tmp=/tmp/jtmp.$$$$; \
		echo sed -f ../subst '<' $$s '>' $$tmp; \
		sed -f ../subst < $$s > $$tmp; \
		echo install -c -m 444 $$tmp $$dst; \
		install -c -m 444 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done

obj:
clean:
cleandir:

.include "../../Makefile.inc"
