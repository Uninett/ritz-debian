#
# $Id$
#

SRC=	../common/util.tcl ../common/conffile.tcl ../common/polljob.tcl \
	../common/config.tcl ../common/justSNMP.tcl tpoller.tcl main.tcl

PROGS=	tpoller start-tpoll

SUBST=	${.CURDIR}/../subst

all: ${PROGS}

tpoller: ${SRC} Makefile
	rm -f $@
	echo "#! "${SCOTTY} > $@
	cat ${SRC} | sed -f ${SUBST} >> $@
	chmod +x $@

start-tpoll: start-tpoll.sh ${SUBST}
	rm -f $@
	sed -f ${SUBST} start-tpoll.sh > $@

install: ${PROGS}
	install -c -m 555 tpoller ${BINDIR}
	install -c -m 555 start-tpoll ${BINDIR}

.include "../Makefile.inc"
