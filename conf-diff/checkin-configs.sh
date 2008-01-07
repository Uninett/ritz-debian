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
start=$TDIR/start-check
newstart=$TDIR/new-start-check
tout=$TDIR/temp-out

trap '/bin/rm -rf $TDIR ; exit 0' EXIT HUP INT QUIT TERM

cd /tftpboot

if [ ! -f $stamp ]; then
	touch $stamp
fi
if [ ! -f $start ]; then
	touch $start
fi
sleep 10	# Allow any "hot files" (being written) to be modified
touch $newstart

maxiter=10
datestr=`date +"%y-%m-%d %H:%M:%S"`
sep="========================================================================"
find . -newer $stamp -name '*-confg' -print > $FLIST 2>/dev/null

while test -s $FLIST; do
    while read f; do
	# Collect diff for possible use later
	rcsdiff -u $f > $tout 2>/dev/null

	# check if there really is a difference
	rcsdiff $f > $TDIR/diff 2>/dev/null
	if [ ! -s $TDIR/diff ]; then
	    continue
	fi

	# Was the file recently written?
	cf=$TDIR/${f}-check
	find $f ! -newer $start > $cf 2>/dev/null
	if [ ! -s $cf -o ! -s $f ]; then
	    # Skip over "hot files", allow them to be picked
	    # up on the next round.
	    echo "Temporarily skipping hot file: " $f >&2
	    continue
	fi

	# We've now committed to record the diff; the file
	# isn't "hot", and we've already collected the diff.
	echo $datestr $f    >> last-checked-files

	echo $sep           >> last-checked-diff
	echo ==== $f =====  >> last-checked-diff
	cat $tout           >> last-checked-diff
	rcs -l $f
	ci -u -m"New config" -t-"Saved config" $f
	chmod 664 $f
    done < $FLIST 
    touch now

    mv $newstart $start
    touch $newstart
    sleep 10

    # Collect new list of files, may pass over some files more than once
    # since we keep the starting point constant through this script
    find . -newer $stamp -name '*-confg' -print | \
	sort - $FLIST | uniq -u > $FLIST.tmp 2>/dev/null
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
