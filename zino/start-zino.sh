#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/zino

# Increase stack size soft limit from 2M to 8M
ulimit -s 8192

../bin/zino >> err 2>&1 &
echo $! > ../zino.pid

exit 0
