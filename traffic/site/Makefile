#
# $Id$
#

all:
install:
obj:
clean:
cleandir:

.if exists(Makefile.inc)
.include "Makefile.inc"
.endif

.include "../../Makefile.inc"

install: beforeinstall
	@for p in ${PICS}; do \
		if [ ! -f ${PICDIR}/$$p ]; then \
			echo install -c -m 444 $$p ${PICDIR}; \
			install -c -m 444 $$p ${PICDIR}; \
		else \
			if ! cmp -s $$p ${PICDIR}/$$p; then \
				echo install -c -m 444 $$p ${PICDIR}; \
				install -c -m 444 $$p ${PICDIR}; \
			fi \
		fi \
	done
	@for f in ${MAPFS}; do \
		if [ ! -f ${MAPDIR}/$$f ]; then \
			echo install -c -m 444 $$f ${MAPDIR}; \
			install -c -m 444 $$f ${MAPDIR}; \
		else \
			if ! cmp -s $$f ${MAPDIR}/$$f; then \
				echo install -c -m 444 $$f ${MAPDIR}; \
				install -c -m 444 $$f ${MAPDIR}; \
			fi \
		fi \
	done
	@if [ "x${HTMLFS}" != "x" ]; then \
		for f in ${HTMLFS}; do \
			if [ ! -f ${HTMLFS}/$$f ]; then \
				echo install -c -m 444 $$f ${HTMLDIR}; \
				install -c -m 444 $$f ${HTMLDIR}; \
			else \
				if ! cmp -s $$f ${MAPDIR}/$$f; then \
					echo install -c -m 444 $$f ${HTMLDIR};\
					install -c -m 444 $$f ${HTMLDIR}; \
				fi \
			fi \
		done \
	fi

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
