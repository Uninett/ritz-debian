#
# $Id$
#

# This Makefile is not referred to from above, installing the on-line
# installation & implementation documentation is optional.

FILES=	basic-inst.html	changes.html	common-pl.html	conf-conv.html \
	features.html 	impl.html	index.html	install.html \
	load-map.html 	plots.html	poller.html	tbl-report.html	\
	todo.html 	tools.html	use-lm.html

DIR=${HTMLDIR}/doc

all:

install:
	@if [ ! -d ${DIR} ]; then \
		echo mkdir ${DIR}; \
		mkdir ${DIR}; \
	fi
	@for f in ${FILES}; do \
		echo install -c -m 444 $$f ${DIR}; \
		install -c -m 444 $$f ${DIR}; \
	done

.include "../../Makefile.inc"
