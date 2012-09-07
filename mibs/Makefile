#
# $Id$
#

FILES=	BGP4-MIB.my CISCO-CDP-MIB.my CISCO-CONFIG-MAN-MIB.my \
	CISCO-PRODUCTS-MIB.my CISCO-SMI.my CISCO-TC.my \
	OLD-CISCO-INTERFACES-MIB.my OLD-CISCO-TCP-MIB.my \
	OLD-CISCO-TS-MIB.my cisco-10-mib.my mib.traps \
	CISCO-IETF-BFD-MIB.my \
	CISCO-VTP-MIB.my CISCO-PIM-MIB.my INET-ADDRESS-MIB.my \
	MSDP-MIB.my CISCO-MAC-NOTIFICATION-MIB.my PIM-MIB.my \
	CISCO-BGP4-MIB.my CISCO-ENVMON-MIB.my BRIDGE-MIB.my \
	ENTITY-MIB.my \
	UNINETT-SMI.my UNINETT-ZINO-MIB.my \
	mib-jnx-chassis-alarm.txt mib-jnx-smi.txt \
	mib-jnx-bfd-exp-mod.txt mib-jnx-exp.txt

MIBDIR=	${TOPDIR}/mibs

all:

install:
	mkdir -p ${MIBDIR}
	@for f in ${FILES}; do \
		echo install -c $$f ${MIBDIR}; \
		install -c $$f ${MIBDIR}; \
	done

clean:

.include "../Makefile.inc"
