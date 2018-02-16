#
# $Id$
#

FILES= 	../common/util.tcl \
	../common/conffile.tcl \
	../common/polljob.tcl \
	../common/config.tcl \
	../common/persist.tcl \
	load-mibs.tcl log.tcl status.tcl bgp.tcl bfd.tcl \
	agent.tcl \
	jnx-alarm.tcl \
	swalk.tcl bwalk.tcl trap.tcl utils.tcl \
	flaps.tcl events.tcl server.tcl auth.tcl \
	pm.tcl \
	../version.tcl \
	zino-main.tcl

PROGS=	zino start-zino tacping linktrap-logger wrap-ltl start-ltl

all: ${PROGS} zino.cf

zino: ${FILES} Makefile
	rm -f zino
	echo "#! "${SCOTTY} > zino
	cat ${FILES} >> zino
	sed -f ../subst < zino > zino.new
	mv zino.new zino
	chmod +x zino

linktrap-logger: load-mibs.tcl linktrap-logger.tcl
	rm -f linktrap-logger
	echo "#! "${SCOTTY} > linktrap-logger
	cat load-mibs.tcl linktrap-logger.tcl >> linktrap-logger
	sed -f ../subst < linktrap-logger > linktrap-logger.new
	mv linktrap-logger.new linktrap-logger
	chmod +x linktrap-logger

wrap-ltl: wrap-ltl.sh
	rm -f wrap-ltl
	sed -f ../subst < wrap-ltl.sh > wrap-ltl
	chmod +x wrap-ltl

start-ltl: start-ltl.sh
	rm -f start-ltl
	sed -f ../subst < start-ltl.sh > start-ltl
	chmod +x start-ltl

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
	@for f in ${PROGS}; do \
		echo install -c -m 555 $$f ${BINDIR}; \
		install -c -m 555 $$f ${BINDIR}; \
	done
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


clean:
	rm -f ${PROGS} zino.cf

.include "../Makefile.inc"
