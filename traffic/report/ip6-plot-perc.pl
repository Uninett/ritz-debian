#! %PERL%
#
# $Id$
#
# Siple script to output percentage of ipv6 packets on
# input and output for a given day.
#
# Usage: perl ip6-plot-perc.pl -d <datespec> <data filename>
#

use Getopt::Std;

use lib "%LIBDIR%";
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
    my($ipkts, $opkts, $iperc, $operc);
    my($i6pkts, $o6pkts);

    $ipkts =
	$count{"ifInUcastPkts",$i} +
	$count{"ifInNUcastPkts",$i};

    $opkts =
	$count{"ifOutUcastPkts",$i} +
	$count{"ifOutNUcastPkts",$i};

    if (defined($count{"ipIfStatsInReceives"})) {
	$i6pkts += $count{"ipIfStatsInReceives"};
	$o6pkts += $count{"ipIfStatsOutTransmits"};
    } else {
	$i6pkts += $count{"ipv6IfStatsInReceives",$i};
	$o6pkts += $count{"ipv6IfStatsOutForwDatagrams",$i};
    }

    if ($ipkts != 0) {
	$iperc = $i6pkts * 100.0 / $ipkts;
    } else {
	$iperc = 0;
    }

    if ($opkts != 0) {
	$operc = $o6pkts * 100.0 / $opkts;
    } else {
	$operc = 0;
    }


    printf("%07.4f %f %f\n",
	   $sample_time{$i},
	   $iperc, $operc
	);
}
