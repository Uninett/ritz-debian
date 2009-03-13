#
# $Id$
#

DOCS=	dsp.html img-doc.html intf-load.html map-doc.html tbl-report.html

PICS=	map-zoom.gif zoom.gif zoom-top10.png

all: zoom.gif

install: beforeinstall
	@for d in ${DOCS}; do \
		echo install -c -m 444 $$d ${HTMLDIR}; \
		install -c -m 444 $$d ${HTMLDIR}; \
	done
	@for p in ${PICS}; do \
		echo install -c -m 444 $$p ${PICDIR}; \
		install -c -m 444 $$p ${PICDIR}; \
	done

beforeinstall:
	@if [ ! -d ${PICDIR} ]; then \
		echo mkdir ${PICDIR}; \
		mkdir ${PICDIR}; \
	else \
		true; \
	fi

zoom.gif: zoom-large.gif
	giftoppm < $? | pnmscale -ysize 400 | ppmquant 40 | ppmtogif > $@

map-base.gif: map-large.gif
	giftoppm < $? | pnmscale -width 500 | ppmquant 150 | ppmtogif > $@

obj:
clean:
cleandir:

.include "../../Makefile.inc"
