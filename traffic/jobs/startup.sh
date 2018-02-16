#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/bin

./start-tpoll
./start-ltl
./start-zino
./start-emt
./start-vwatch

exit 0
