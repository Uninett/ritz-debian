#
# $Id$
#

FILES= load-mibs.tcl log.tcl status.tcl swalk.tcl trap.tcl utils.tcl \
	flaps.tcl events.tcl server.tcl auth.tcl \
	../common/conffile.tcl \
	../common/config.tcl \
	../common/polljob.tcl \
	../common/persist.tcl \
	zino-main.tcl

all: zino

zino: $(FILES)
	rm -f zino
	echo "#!/store/bin/scotty" > zino
	cat $(FILES) >> zino
	chmod +x zino

clean:
	rm -f zino
