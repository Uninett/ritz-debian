#
# $Id$
#

SRCS=	../version.tcl just/justSNMP.tcl just/prettySNMP.tcl \
	just/mib2util.tcl \
	attrs.tcl net.tcl notify.tcl sort.tcl summary.tcl ui.tcl \
	utils.tcl main.tcl bgerror.tcl

all: ritz

../version.tcl: ../Makefile
	(cd ..; make version.tcl)

ritz: ${SRCS} Makefile
	rm -f $@
	echo "#! "${WISH} > $@
	echo "#" >> $@
	echo "# DO NOT EDIT, AUTOMATICALLY GENERATED!!" >> $@
	echo "#" >> $@
	echo "" >> $@
	for f in ${SRCS}; do \
		cat $$f >> $@; \
	done
	echo "main" >> $@
	chmod +x $@

install:
	rm -f ${BINDIR}/ritz
	cp ritz ${BINDIR}/ritz

clean:
	rm -f ritz

.include "../Makefile.inc"
