#
# $Id$
#

FILES=	Zino.pm zino-monitor.pl emt-config.tcl

PROGS=	zinomon zino-monitor.pl emt-config

LIBS=	Zino.pm

all: ${PROGS}

zinomon: zinomon.sh
	rm -f $@
	sed -f ../subst $@.sh > $@
	chmod +x $@

emt-config: emt-config.tcl
	rm -f $@
	sed -f ../subst $@.tcl > $@
	chmod +x $@

install: ${PROGS}
	for f in ${LIBS}; do \
		install -c -m 555 $$f ${LIBDIR}; \
	done
	for f in ${PROGS}; do \
		install -c -m 555 $$f ${BINDIR}; \
	done

clean:
	rm -f ${PROGS}

.include "../Makefile.inc"

