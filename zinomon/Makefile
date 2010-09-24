#
# $Id$
#

FILES=	Zino.pm zino-monitor.pl emt-config.tcl

PPROGS=	zino-monitor.pl
GPROGS= zinomon emt-config

LIBS=	Zino.pm

all: ${GPROGS} ${PPROGS}

zinomon: zinomon.sh
	rm -f $@
	sed -f ../subst $@.sh > $@
	chmod +x $@

emt-config: emt-config.tcl
	rm -f $@
	sed -f ../subst $@.tcl > $@
	chmod +x $@

install: ${GPROGS} ${PPROGS}
	@for f in ${LIBS}; do \
		echo install -c -m 555 $$f ${LIBDIR}; \
		install -c -m 555 $$f ${LIBDIR}; \
	done
	@for f in ${GPROGS} ${PPROGS}; do \
		echo install -c -m 555 $$f ${BINDIR}; \
		install -c -m 555 $$f ${BINDIR}; \
	done

clean:
	rm -f ${GPROGS}

.include "../Makefile.inc"

