#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/zino

../bin/zino >> err 2>&1 &
echo $! > ../zino.pid

exit 0
