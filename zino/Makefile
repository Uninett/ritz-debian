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

all: zino

zino: $(FILES) Makefile
	rm -f zino
	echo "#!/store/bin/scotty" > zino
	cat $(FILES) >> zino
	chmod +x zino

clean:
	rm -f zino
