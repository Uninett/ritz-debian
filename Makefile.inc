#							-*- Makefile -*-
# $Id$
#

# Top-level directory of traffic statistics tree
#
TOPDIR=/local/traffic
#
# Add more, space-separated, if needed
#
DATA_ROOTS="${TOPDIR}/data"
#
# Must be Perl v5
PERL=/usr/bin/perl
#
CGIPFX=/stat-q
WEBSRVR=betong.veidekke.no
HTMLDIR=${TOPDIR}/html
# HTMLPFX has to be only one path component (due to cgi/ex-png.pl).
HTMLPFX=/stats
GNUPLOT=/usr/pkg/bin/gnuplot
GZCAT=/usr/bin/gzcat
GZIP=/usr/bin/gzip
GUNZIP=/usr/bin/gunzip
ZCAT=/usr/bin/zcat
PING=/sbin/ping
SCOTTY=/usr/pkg/bin/scotty
SNMPNETSTAT=/local/bin/snmpnetstat
#
NOTIFY=he
CHECKINTV=400
MAIL=/usr/bin/mail
#
# Cached data (png/plot files) not accessed
# in this number of days will be removed
CACHETTL=14
#
# When did we start collecting data?
DATASTART=20000714
#

# ------------------------------
# NO tweakables beyond this line
# ------------------------------

BINDIR=${TOPDIR}/bin
CGIDIR=${TOPDIR}/cgi
CONFDIR=${TOPDIR}/conf
DATADIR=${TOPDIR}/data
DBDIR=${TOPDIR}/db
LIBDIR=${TOPDIR}/lib
MAPDIR=${TOPDIR}/maps
MIBDIR=${TOPDIR}/mibs
PLOTDIR=${TOPDIR}/plot
REPDIR=${TOPDIR}/reports
#
IMGDIR=${HTMLDIR}/imgs
MREPDIR=${REPDIR}/monthly
PICDIR=${HTMLDIR}/pics
PLOTDATADIR=${DATADIR}/plot
PLOTCACHE=${PLOTDATADIR}/plt-cache
TODAYDIR=${DATADIR}/today
WREPDIR=${REPDIR}/weekly
