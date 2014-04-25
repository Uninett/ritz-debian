#
# $Id$
#

SRCS=	../version.tcl just/justSNMP.tcl just/prettySNMP.tcl \
	just/mib2util.tcl \
	attrs.tcl net.tcl notify.tcl sort.tcl summary.tcl ui.tcl \
	utils.tcl main.tcl bgerror.tcl

CLISRCS= net.tcl cli.tcl


all: ritz cli

../version.tcl: ../Makefile
	(cd ..; make version.tcl)

ritz: ${SRCS} Makefile ../subst
	rm -f $@
	echo "#! "${WISH} > $@
	echo "#" >> $@
	echo "# DO NOT EDIT, AUTOMATICALLY GENERATED!!" >> $@
	echo "#" >> $@
	echo "option clear" >> $@
	echo "package require Tix" >> $@
	echo "" >> $@
	for f in ${SRCS}; do \
		cat $$f >> $@; \
	done
	echo "main" >> $@
	sed -f ../subst $@ > $@.new
	mv $@.new $@
	chmod +x $@

cli: ${CLISRCS} Makefile ../subst
	rm -f $@
	echo "#! "${SCOTTY} > $@
	echo "#" >> $@
	echo "# DO NOT EDIT, AUTOMATICALLY GENERATED!!" >> $@
	echo "#" >> $@
	echo "" >> $@
	for f in ${CLISRCS}; do \
		cat $$f >> $@; \
	done
	echo "main" >> $@
	sed -f ../subst $@ > $@.new
	mv $@.new $@
	chmod +x $@

install: ritz cli
	rm -f ${BINDIR}/ritz
	cp ritz ${BINDIR}/ritz
	rm -f ${BINDIR}/cli
	cp ritz ${BINDIR}/cli

clean:
	rm -f ritz
	rm -f cli

.include "../Makefile.inc"
