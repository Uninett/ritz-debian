#
# $Id$
#

LIBFILES=db-lookup.pl

PROGS=	dbm-edit dbm-dump.pl dbm-load.pl update-dbs.pl

all:

install:
	@for s in ${PROGS}; do \
		dst=${BINDIR}/`basename $$s .pl`; \
		tmp=/tmp/dbtmp.$$$$; \
		echo sed -f ../subst '<' $$s '>' $$tmp; \
		sed -f ../subst < $$s > $$tmp; \
		echo install -c -m 555 $$tmp $$dst; \
		install -c -m 555 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done
	@for s in ${LIBFILES}; do \
		dst=${LIBDIR}/$$s; \
		tmp=/tmp/comtmp.$$$$; \
		echo sed -f ${.CURDIR}/../subst '<' $$s '>' $$tmp; \
		sed -f ${.CURDIR}/../subst < $$s > $$tmp; \
		echo install -c -m 444 $$tmp $$dst; \
		install -c -m 444 $$tmp $$dst; \
		echo rm -f $$tmp; \
		rm -f $$tmp; \
	done

obj:
clean:
cleandir:

.include "../../Makefile.inc"
