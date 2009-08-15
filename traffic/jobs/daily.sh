#! /bin/sh
#
# $Id$
#

umask 2

nice %TOPDIR%/bin/daily.pl
%TOPDIR%/bin/update-dbs -v -n -t %TOPDIR%
%TOPDIR%/bin/daily-clean

#
# Save any RRD-data on the first of each month
#

sleep 180	# cron job itself starts 3 min before midnight
sleep 900	# cron jobs run with 10-15 minute frequency, wait one period
sleep %TAILDELAY% # Make sure we have processed all the data:

d=`date +%d`
data=%TOPDIR%/data
if [ "$d" = "01" -a -d $data/cust-rrd ]; then
	dstr=`date +%Y%m%d`
	savedir=$data/cust-rrd-$dstr
	mkdir $savedir
	cp $data/cust-rrd/* $savedir
fi
