#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/bin

./start-tpoll
./start-zino
./start-emt
./start-vwatch

exit 0
