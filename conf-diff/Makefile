#
# $Id$
#

SRCS=	post-diff.sh checkin-configs.sh

PROGS=	post-diff checkin-configs

all: ${PROGS}

post-diff: post-diff.sh ../subst
	sed -f ../subst post-diff.sh > post-diff

checkin-configs: checkin-configs.sh ../subst
	sed -f ../subst checkin-configs.sh > checkin-configs

install: ${PROGS}
	install -c -m 555 post-diff ${BINDIR}
	install -c -m 555 checkin-configs ${BINDIR}

clean:
	rm -f ${PROGS}

.include "../Makefile.inc"
