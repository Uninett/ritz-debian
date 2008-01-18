#
# $Id$
#

FILES= 	../common/util.tcl \
	../common/conffile.tcl \
	../common/polljob.tcl \
	../common/config.tcl \
	../common/persist.tcl \
	load-mibs.tcl log.tcl status.tcl bgp.tcl \
	jnx-alarm.tcl \
	swalk.tcl trap.tcl utils.tcl \
	flaps.tcl events.tcl server.tcl auth.tcl \
	zino-main.tcl

PROGS=	zino start-zino tacping

all: ${PROGS} zino.cf

zino: ${FILES} Makefile
	rm -f zino
	echo "#! "${SCOTTY} > zino
	cat ${FILES} >> zino
	sed -f ../subst < zino > zino.new
	mv zino.new zino
	chmod +x zino

zino.cf: zino.cf.tmpl ../subst
	rm -f zino.cf
	sed -f ../subst < zino.cf.tmpl > zino.cf

start-zino: start-zino.sh ../subst
	rm -f start-zino
	sed -f ../subst < start-zino.sh > start-zino

tacping: tacping.pl ../subst
	rm -f tacping
	sed -f ../subst <tacping.pl > tacping

install: ${PROGS} zino.cf
	@if [ ! -d ${ZINODIR} ]; then \
		echo mkdir -p ${ZINODIR}; \
		mkdir -p ${ZINODIR}; \
	fi
	install -c -m 555 zino ${BINDIR}
	install -c -m 555 start-zino ${BINDIR}
	install -c -m 444 zino.cf ${ZINODIR}
	@if [ ! -f ${ZINODIR}/eventid ]; then \
		echo "echo 0 > ${ZINODIR}/eventid"; \
		echo 0 > ${ZINODIR}/eventid; \
	fi
	@for f in secrets save-state.tcl; do \
		if [ ! -f ${ZINODIR}/$$f ]; then \
			echo install -c -m 600 /dev/null ${ZINODIR}/$$f; \
			install -c -m 600 /dev/null ${ZINODIR}/$$f; \
		fi; \
	done
	install -c -m 555 tacping ${BINDIR}


clean:
	rm -f ${PROGS} zino.cf

.include "../Makefile.inc"
