#!/bin/sh

# $Id$

# Fix up all the data files given on the command line. 

for f; do
    gz=0
    b=$f
    if expr $f : '.*\.gz$' >/dev/null 2>&1; then
	gz=1
	%GUNZIP% $f
	b=`echo $f | sed -e 's/\.gz$//'`
    fi
    %TOPDIR%/bin/fixup-data.pl <$b >$b.new
    mv $b.new $b
    if [ $gz = 1 ]; then
	%GZIP% $b
    fi
done
