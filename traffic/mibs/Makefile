#
# $Id$
#

FILES=	CISCO-SMI.my OLD-CISCO-INTERFACES-MIB.my

all:

install:
	@for f in ${FILES}; do \
		echo install -c -m 444 $$f ${MIBDIR}; \
		install -c -m 444 $$f ${MIBDIR}; \
	done

obj:
clean:
cleandir:

.include "../Makefile.inc"
