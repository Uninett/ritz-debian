#!/bin/sh
#
# $Id$
#

cd %TOPDIR%

bin/vwatch > vw.err 2>&1 &
echo $! > vw.pid

exit 0
