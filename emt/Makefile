#
# $Id$
#

TCLSH=	/usr/pkg/bin/tclsh8.0
BINDIR=	/local/bin

SRCS=	\
	../common/attrs.tcl \
	../common/auth.tcl \
	../common/cp.tcl \
	../common/net.tcl \
	../common/notify.tcl \
	../common/persist.tcl \
	../common/sort.tcl \
	emt.tcl

all: emt

emt: ${SRCS} Makefile
	rm -f $@
	echo "#! "${TCLSH} > $@
	echo "# -*- Tcl -*- " >> $@
	echo "# DO NOT EDIT, AUTOMATICALLY GENERATED!!" >> $@
	echo "#" >> $@
	echo "" >> $@
	for f in ${SRCS}; do \
		cat $$f >> $@; \
	done
	echo "emt_main" >> $@
	chmod +x $@

install:
	rm -f ${BINDIR}/emt
	install -c -m 755 emt ${BINDIR}/emt

clean:
	rm -f emt
