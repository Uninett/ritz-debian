#!/bin/sh
#
# $Id$
#

umask 2

nice %TOPDIR%/bin/daily.pl
%TOPDIR%/bin/update-dbs <%CONFDIR%/ifs.cf
%TOPDIR%/bin/daily-clean
