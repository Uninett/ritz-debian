#!/bin/sh
#
# $Id$ 
#

# Daily cleanup of cache directories, discard data not accessed
# in %CACHETTL% days.

DIRS="%IMGDIR% %PLOTCACHE%"

for d in ${DIRS}; do
    find $d -type f -atime +%CACHETTL% -print | xargs rm -f
done

