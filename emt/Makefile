#
# $Id$
#

TCLSH=/store/bin/tclsh
BINDIR=/local/bin

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
	echo "#!"${TCLSH} > $@
	echo "# -*- Tcl -*- " >> $@
	echo "#" >> $@
	echo "" >> $@
	echo "#" >> $@
	echo "# DO NOT EDIT, AUTOMATICALLY GENERATED!!" >> $@
	echo "#" >> $@
	echo "" >> $@
	for f in ${SRCS}; do \
		echo "#" >> $@; \
		echo "# Start " $$f >> $@; \
		echo "#" >> $@; \
		cat $$f >> $@; \
		echo "#" >> $@; \
		echo "# End " $$f >> $@; \
		echo "#" >> $@; \
	done
	echo "" >> $@
	echo "#" >> $@
	echo "# And now, call main procedure" >> $@
	echo "#" >> $@
	echo "" >> $@
	echo "emt_main" >> $@
	chmod +x $@

install:
	rm -f ${BINDIR}/emt
	cp emt ${BINDIR}/emt

clean:
	rm -f emt
