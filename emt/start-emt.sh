#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/emt
../bin/emt >> emt.err 2>&1 &
echo $! > ../emt.pid

exit 0
