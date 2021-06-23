#! /bin/sh

# $Id$

while true; do
    %BINDIR%/linktrap-logger >> ltl.log 2>&1

    # If it continually fails, slow it down a little...
    sleep 10

    # Save any core file, keep 10 of them
    corefile=scotty2.1.11.core
    if [ -f $corefile ]; then
	for n in $(jot 10 0 | tail -r); do
	    if [ -f ${corefile}.$n ]; then
		nxt=$(expr $n + 1)
		mv ${corefile}.$n ${corefile}.$nxt
	    fi
	done
	mv ${corefile} ${corefile}.0
    fi
done
    