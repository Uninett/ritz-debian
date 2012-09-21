#! /usr/bin/perl
#
# $Id$
#
# Test of read-raw-log, looking at DST switchover
#

use Getopt::Std;

use lib "/local/traffic/lib";
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

for(my $i = 0; $i <= $max_sample; $i++) {
    printf("%07.4f %f\n", $sample_time{$i}, $count{"ifHCInOctets",$i});
}
