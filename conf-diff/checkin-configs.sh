#!/bin/sh
#
# $Id$
#

stamp="last-checked-in"

umask 077
TDIR=/tftpboot/_secdir.$$
if mkdir $TDIR; then
	:
else
	echo "Can't create $TDIR" >&2
	exit 1
fi
umask 022

FLIST=$TDIR/modified

trap '/bin/rm -rf $TDIR ; exit 0' EXIT HUP INT QUIT TERM

cd /tftpboot

if [ ! -f $stamp ]; then
	touch $stamp
fi

maxiter=10
datestr=`date +"%y-%m-%d %H:%M:%S"`
sep="========================================================================"
find . -newer $stamp -name '*-confg' -print > $FLIST

while test -s $FLIST; do
    while read f; do
	# Skip over empty files (and delay), since tftpd may be in the
	# process of writing, and tftpd now truncates the output before
	# it is written.
	if [ ! -s $f ]; then
	    sleep 20	# Give write a fair chance to complete
	    continue
	fi
	echo $datestr $f >> last-checked-files

	rcsdiff $f > $TDIR/diff 2>/dev/null
	if [ ! -s $TDIR/diff ]; then
	    continue
	fi

	echo $sep >> last-checked-diff
	echo ==== $f =====>> last-checked-diff
	# Compensate for tftpds which do not truncate the output
	# before writing, and erase text after '^end$' if there is
	# such an occurrance (assumed to be a cisco config).
	if egrep '^end$' $f >/dev/null 2>&1; then
	    bn=`basename $f`
	    if sed '/^end$/q' $f > $TDIR/$bn; then
		mv -f $TDIR/$bn $f
	    fi
	fi
	rcsdiff -u $f >> last-checked-diff 2>/dev/null
	rcs -l $f
	ci -u -m"New config" -t-"Saved config" $f
    done < $FLIST 
    touch now

    # Check if any new configs have been written while we were
    # checking in our stuff, redo for those files
    find . -newer $stamp -name '*-confg' -print | \
	sort - $FLIST | uniq -u > $FLIST.tmp
    mv $FLIST.tmp $FLIST
    maxiter=`expr $maxiter - 1`;
    if [ $maxiter -le 0 ]; then
	echo "Too many iterations" >&2
	exit 1
    fi
done

if [ -f now ]; then
	mv now $stamp
fi

exit 0
