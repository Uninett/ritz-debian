#
# $Id$
#

# These two are about to be obsoleted
PICS=	ndn-map.gif
COORDS=	ndn-map.coords

MAPFS=	ndn-map.fig default.rng
HTMLFS=	index.html


all:

install: beforeinstall
	@for p in ${PICS}; do \
		echo install -c -m 444 $$p ${PICDIR}; \
		install -c -m 444 $$p ${PICDIR}; \
	done
	@for m in ${COORDS}; do \
		echo install -c -m 444 $$m ${DBDIR}; \
		install -c -m 444 $$m ${DBDIR}; \
	done
	@for f in ${MAPFS}; do \
		echo install -c -m 444 $$f ${MAPDIR}; \
		install -c -m 444 $$f ${MAPDIR}; \
	done
	@for f in ${HTMLFS}; do \
		echo install -c -m 444 $$f ${HTMLDIR}; \
		install -c -m 444 $$f ${HTMLDIR}; \
	done

beforeinstall:
	@if [ ! -d ${PICDIR} ]; then \
		echo mkdir ${PICDIR}; \
		mkdir ${PICDIR}; \
	else \
		true; \
	fi
	@if [ ! -d ${MAPDIR} ]; then \
		echo mkdir ${MAPDIR}; \
		mkdir ${MAPDIR}; \
	else \
		true; \
	fi


obj:
clean:
cleandir:

.include "../Makefile.inc"
