#
# $Id$
#

SRC=	../common/util.tcl ../common/conffile.tcl ../common/polljob.tcl \
	../common/config.tcl ../common/justSNMP.tcl tpoller.tcl main.tcl
PROG=	tpoller
SCOTTY=	/usr/pkg/bin/scotty
BINDIR=	/local/traffic/bin

all: ${PROG}

${PROG}: ${SRC}
	rm -f ${PROG}
	echo "#! "${SCOTTY} > ${PROG}
	cat ${SRC} >> ${PROG}
	chmod +x ${PROG}

install: ${PROG}
	install -c -m 755 ${PROG} ${BINDIR}