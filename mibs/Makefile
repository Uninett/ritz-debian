#
# $Id$
#

FILES=	BGP4-MIB.my CISCO-CDP-MIB.my CISCO-CONFIG-MAN-MIB.my \
	CISCO-PRODUCTS-MIB.my CISCO-SMI.my CISCO-TC.my \
	OLD-CISCO-INTERFACES-MIB.my OLD-CISCO-TCP-MIB.my \
	OLD-CISCO-TS-MIB.my cisco-10-mib.my mib.traps

MIBDIR=/local/traffic/mibs

all:

install:
	@for f in ${FILES}; do \
		echo install -c $$f ${MIBDIR}; \
		install -c $$f ${MIBDIR}; \
	done
