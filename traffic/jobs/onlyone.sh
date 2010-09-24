#! /bin/sh

# $Id$

#
# Script to ensure that only a single instance of a given job runs at
# any one time.
#
# Relies on NetBSD's "shlock" program.
#

if [ "x$1" = "x" -o "x$2" = "x" ]; then
    echo "usage: $0 lockname commandline" >&2
    exit 1
fi

lock=/tmp/$1			# so this goes away on reboot
shift

if shlock -f ${lock} -p $$; then
    eval "$@"
    e=$?
    rm ${lock}
    exit $e
else
    echo "pid " `cat ${lock}` " already running: " "$@" >&2
    exit 1
fi
