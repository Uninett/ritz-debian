#! /usr/bin/perl
#
# $Id$
#
# Test of read-raw-log, looking at DST switchover
#

use Getopt::Std;

use lib "/local/traffic/lib";
require "read-hr-log.pl";
require "date.pl";
require "utils.pl";

use strict;

#
# Main
#

our($opt_d, $opt_n);

&getopts("d:n:");

my($f) = $ARGV[0];
our(%count, $max_sample, %sample_time, %max_rate);

if (!defined($opt_n)) {
	$opt_n = 1;
}

for (my $n = 0; $n < $opt_n; $n++) {
	my($IN);
	open($IN, $f) || die "Could not open $f for read: $!";
	my($tm, $nd) = &decode_datespec($opt_d);

	&read_log($IN, $tm);
	close($IN);
}

for(my $h = 0; $h < 24; $h++) {
    $h = sprintf("%02d", $h);
    printf("%s %18f %18f\n",
	   $h,
	   $count{"ifHCInOctets",$h} / 3600.0,
	   $max_rate{"ifHCInOctets",$h},
	);
}
