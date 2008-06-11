#
# $Id$
#

CONFS=	zino-config.pl

SCRIPTS=daily-clean.sh daily.sh daily.pl dst-shift.pl \
	fixup-data.pl fixup-data.sh startup.sh onlyone.sh \
	compress-data.pl

SUBST=	${.CURDIR}/../../subst

all:

install:
	@for s in ${SCRIPTS}; do \
		base=`basename $$s .sh`; \
		dst=${BINDIR}/$$base; \
		tmp=/tmp/jtmp.$$$$; \
		echo sed -f ${SUBST} '<' $$s '>' $$tmp; \
		sed -f ${SUBST} < $$s > $$tmp; \
		if egrep '%[A-Z_]*%' $$tmp; then \
			echo "Remaining substitution in $$s" >&2; \
			echo "May need to update top-level Makefile.inc" >&2; \
			rm -f $$tmp; \
			exit 1; \
		fi; \
		echo install -c -m 555 $$tmp $$dst; \
		install -c -m 555 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done
	@for s in ${CONFS}; do \
		dst=${CONFDIR}/$$s; \
		tmp=/tmp/jtmp.$$$$; \
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
