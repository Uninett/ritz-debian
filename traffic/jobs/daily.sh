#! /bin/sh
#
# $Id$
#

umask 2

nice %TOPDIR%/bin/daily.pl
%TOPDIR%/bin/update-dbs -f %TOPDIR%/conf/polldevs.cf -d %TOPDIR%/db
%TOPDIR%/bin/daily-clean
