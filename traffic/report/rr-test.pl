#! /usr/bin/perl
#
# $Id$
#
# Test of read-raw-log, looking at DST switchover
#

use Getopt::Std;

use lib "/a/traffic/lib";
require "read-raw-log.pl";
require "date.pl";


use strict;

#
# Main
#

our($opt_d);

&getopts("d:");

my($f) = $ARGV[0];
my($IN);
open($IN, $f) || die "Could not open $f for read: $!";
my($tm, $nd) = &decode_datespec($opt_d);

our(%count, $max_sample, %sample_time);

&read_log($IN, $tm);

our($ifspeed);

our($iov, $oov);

if (defined($count{"ifHCInOctets",0})) {
    $iov = "ifHCInOctets";
    $oov = "ifHCOutOctets";
} else {
    $iov = "ifInOctets";
    $oov = "ifOutOctets";
}

for(my $i = 1; $i <= $max_sample; $i++) {
    my $td = $sample_time{$i} - $sample_time{$i-1};
    my $ir = $count{$iov,$i} * 8 / ($td * 3600);
    my $or = $count{$oov,$i} * 8 / ($td * 3600);
    my $m = "";
    if ($ir > $ifspeed || $or > $ifspeed) {
	$m = " <-- " . $ifspeed;
    }
    printf("%07.4f %10.0f %10.0f%s\n",
	$sample_time{$i},
	$ir, $or, $m
	);
}
