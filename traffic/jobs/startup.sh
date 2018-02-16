#!/bin/sh
#
# $Id$
#

cd %TOPDIR%/bin

./start-tpoll
./start-zino
./start-emt
./start-vwatch
./start-ltl

exit 0
