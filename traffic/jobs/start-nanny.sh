#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/bin

./nanny.pl >>../nanny.errs 2>&1 &

exit 0
