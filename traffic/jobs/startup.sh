#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/bin

%SCOTTY% ./poller >>../poller.errs 2>&1 &
echo $! > ../poller.pid

exit 0
