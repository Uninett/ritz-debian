#
# $Id$
#

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

emt: ${SRCS} Makefile ../subst
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
	mv $@ $@.new
	sed -f ../subst $@.new > $@
	chmod +x $@

install:
	rm -f ${BINDIR}/emt
	install -c -m 755 emt ${BINDIR}/emt

clean:
	rm -f emt

.include "../Makefile.inc"
