#
# $Id$
#

FILES= 	../common/util.tcl \
	../common/conffile.tcl \
	../common/polljob.tcl \
	../common/config.tcl \
	../common/persist.tcl \
	load-mibs.tcl log.tcl status.tcl swalk.tcl trap.tcl utils.tcl \
	flaps.tcl events.tcl server.tcl auth.tcl \
	zino-main.tcl

all: zino zino.cf

zino: $(FILES) Makefile
	rm -f zino
	echo "#! "${SCOTTY} > zino
	cat $(FILES) >> zino
	chmod +x zino

zino.cf: zino.cf.tmpl ../subst
	sed -f ../subst < zino.cf.tmpl > zino.cf

install: zino
	install -c -m 555 zino ${BINDIR}
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
	rm -f zino

.include "../Makefile.inc"
