#! /bin/sh
#
# $Id$
#

umask 2

nice %TOPDIR%/bin/daily.pl
%TOPDIR%/bin/update-dbs -t %TOPDIR%
%TOPDIR%/bin/daily-clean
