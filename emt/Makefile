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

PROGS=emt start-emt

all: ${PROGS}

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
	rm -f $@.new

start-emt: start-emt.sh ../subst
	sed -f ../subst start-emt.sh > start-emt

install: ${PROGS}
	install -c -m 555 emt ${BINDIR}
	install -c -m 555 start-emt ${BINDIR}
	@if [ ! -d ${BINDIR}/../emt ]; then \
		echo mkdir ${BINDIR}/../emt; \
		mkdir ${BINDIR}/../emt; \
	fi
	@if [ ! -f ${BINDIR}/../emt/emt-save.tcl ]; then \
		echo touch ${BINDIR}/../emt/emt-save.tcl; \
		touch ${BINDIR}/../emt/emt-save.tcl; \
	fi

clean:
	rm -f ${PROGS}

.include "../Makefile.inc"
