#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/conf

../bin/tpoller >>../tp.err 2>&1 &
echo $! > ../tpoller.pid

exit 0
