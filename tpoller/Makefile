#
# $Id$
#

SRC=	../common/util.tcl ../common/conffile.tcl ../common/polljob.tcl \
	../common/config.tcl ../common/justSNMP.tcl tpoller.tcl main.tcl
PROG=	tpoller

all: ${PROG}

${PROG}: ${SRC}
	rm -f ${PROG}
	echo "#! "${SCOTTY} > ${PROG}
	cat ${SRC} >> ${PROG}
	chmod +x ${PROG}

install: ${PROG}
	install -c -m 755 ${PROG} ${BINDIR}

.include "../Makefile.inc"
