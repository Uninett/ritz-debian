#
# $Id$
#

SRC=	../common/util.tcl ../common/conffile.tcl ../common/polljob.tcl \
	../common/config.tcl ../common/justSNMP.tcl tpoller.tcl main.tcl

PROGS=	tpoller start-tpoll.sh

all: ${PROGS}

tpoller: ${SRC}
	rm -f $@
	echo "#! "${SCOTTY} > $@
	cat ${SRC} >> $@
	chmod +x $@

start-tpoll: start-tpoll.sh ../subst
	sed -f ../subst start-tpoll.sh > $@

install: ${PROGS}
	install -c -m 555 tpoller ${BINDIR}
	install -c -m 555 start-tpoll ${BINDIR}

.include "../Makefile.inc"
