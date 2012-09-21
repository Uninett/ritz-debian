#!%PERL%
#
# $Id$
#

# Copyright (c) 1996, 1997
#      UNINETT and NORDUnet.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#      This product includes software developed by UNINETT and NORDUnet.
# 4. Neither the name of UNINETT or NORDUnet nor the names
#    of its contributors may be used to endorse or promote
#    products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY UNINETT AND NORDUnet ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL UNINETT OR NORDUnet OR
# THEIR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Produce reports for a week's worth of traffic
#
# Input: day in either of forms (dd / mm-dd / yyyy-mm-dd)
#        report is for "previous week", Mon - Sun
#   or
#        [-w week [-y year]]
#   or
#        empty (data for previous week will be processed)
#
# Output in several files in report/weekly/yyyy/ww/*.
# Files:
#   traffic	Traffic report
#
#
# Possible heading for traffic:
#
# Intf.       Peak    Busy        Busy day       Week                  Median
#           sample    hour     input  output  average   speed         90% load
#          %in out  %in out  %   day %   day  %in out  kbit/s  iftype  in  out
#xxxxxxxxx xxx xxx  xxx xxx  xxx xxx xxx xxx  xxx xxx  xxxxxx  xx     xxx  xxx
#
#
# Possible heading for traffic.kbit:
#
# Intf   Peak sample      Busy hour  Busy day(24h)   Week average  speed
#       input output   input output   input output   input output kbit/s iftype
#xxxxx xxxxxx xxxxxx  xxxxxx xxxxxx  xxxxxx xxxxxx  xxxxxx xxxxxx xxxxxx xxxxxx
#
# plus
#        Median 90%
#       input output
#      xxxxxx xxxxxx
#
# (yes, it exceeds 80 coloums.)
#
# Possible heading for errors.perc:
#
# Port      hrs>=%InErr   In-errs    Ignores     Resets      Out Discard %
#           1.0 0.1 .01  PDay  Avg  PDay  Avg  total PkDay  PkHr PDay  Avg iftp
#xxxxxxxxxx xxx xxx xxx  xxxx xxxx  xxxx xxxx  xxxxx xxxxx  xxxx xxxx xxxx xxxx
#
# NOTE: intf/Interface coloumns should be 25 chars, this will push the
# rightmost coloumn over 80.
#

push(@INC, "%LIBDIR%");

use Getopt::Std;

require 'date.pl';
require 'search.pl';
require 'read-day-report.pl';
require 'utils.pl';

# suck in and post-process data

sub get_all_data {
    my($week, $year) = @_;
    my($base_tm, $tm, $date, $dn);

    $base_tm = &firstinweek($week, $year);
    foreach $d (0 .. 6) {
	$tm = $base_tm + $d * (60*60*24);
	$date = &tm_to_date($tm);
	$dn = &find_day_report_dir(&tm_to_datespec($tm, "day"));
	open(IN, $dn . "/traffic") || next;
#	printf("Reading traffic for date %s\n", $date);
	&read_traffic(IN, $date);
	close(IN);
	foreach $intf (keys %intf) {
	    if (defined($iftype{$intf, $date})) { # have data for date
		$busy_in{$intf} = &max($busy_in{$intf},
				       $busy_load_in{$intf, $date});
		$busy_out{$intf} = &max($busy_out{$intf},
					$busy_load_out{$intf, $date});
		$peak_in{$intf} = &max($peak_in{$intf},
				       $peak_load_in{$intf, $date});
		$peak_out{$intf} = &max($peak_out{$intf},
				       $peak_load_out{$intf, $date});
		if (!defined($busy_ave_in{$intf}) ||
		    $busy_ave_in{$intf} <= $average_load_in{$intf, $date})
		{
		    $busy_ave_in{$intf} =  $average_load_in{$intf, $date};
		    $busy_day_in{$intf} =  $d;
		}
		if (!defined($busy_ave_out{$intf}) ||
		    $busy_ave_out{$intf} <= $average_load_out{$intf, $date})
		{
		    $busy_ave_out{$intf} =  $average_load_out{$intf, $date};
		    $busy_day_out{$intf} =  $d;
		}
		$sum_in{$intf} += $average_load_in{$intf, $date};
		$sum_out{$intf} += $average_load_out{$intf, $date};
		$counts{$intf}++;
		$type{$intf} = $iftype{$intf, $date}; # use last value
		$speed{$intf} = $ifspeed{$intf, $date};	# use last value
		push( @{ $in_90percs{$intf} }, $in_90perc{$intf, $date});
		push( @{ $out_90percs{$intf} }, $out_90perc{$intf, $date});
	    }
	}
	undef(%intf);
	undef(%busy_load_in);
	undef(%busy_load_out);
	undef(%peak_load_in);
	undef(%peak_load_out);
	undef(%average_load_in);
	undef(%average_load_out);
	undef(%ifspeed);
	undef(%iftype);
	undef(%in_90perc);
	undef(%out_90perc);

	open(IN, $dn . "/traffic.kbit") || next;
#	printf("Reading traffic.kbit for date %s\n", $date);
	&read_traffic_kbit(IN, $date);
	close(IN);
	foreach $intf (keys %intf) {
	    if (defined($iftype{$intf, $date})) { # Have data for date
		$busy_kbit_in{$intf} = &max($busy_kbit_in{$intf},
					    $busy_load_in{$intf, $date});
		$busy_kbit_out{$intf} = &max($busy_kbit_out{$intf},
					     $busy_load_out{$intf, $date});
		$peak_kbit_in{$intf} = &max($peak_kbit_in{$intf},
					    $peak_load_in{$intf, $date});
		$peak_kbit_out{$intf} = &max($peak_kbit_out{$intf},
					     $peak_load_out{$intf, $date});
		if ($busy_ave_kbit_in{$intf} <=
		    $average_load_in{$intf, $date})
		{
		    $busy_ave_kbit_in{$intf} = $average_load_in{$intf, $date};
		    $busy_day_kbit_in{$intf} = $d;
		}
		if ($busy_ave_kbit_out{$intf} <=
		    $average_load_out{$intf, $date})
		{
		    $busy_ave_kbit_out{$intf}= $average_load_out{$intf, $date};
		    $busy_day_kbit_out{$intf}= $d;
		}
		$sum_in_kbit{$intf} += $average_load_in{$intf, $date};
		$sum_out_kbit{$intf} += $average_load_out{$intf, $date};
		$counts_kbit{$intf}++;
		push( @{ $in_90p_kbits{$intf} },  $in_90perc{$intf, $date});
		push( @{ $out_90p_kbits{$intf} }, $out_90perc{$intf, $date});
	    }
	}
	undef(%intf);
	undef(%busy_load_in);
	undef(%busy_load_out);
	undef(%peak_load_in);
	undef(%peak_load_out);
	undef(%average_load_in);
	undef(%average_load_out);
	undef(%ifspeed);
	undef(%iftype);
	undef(%in_90perc);
	undef(%out_90perc);

	open(IN, $dn . "/errors.perc") || next;
#	printf("Reading errors.perc for date %s\n", $date);
	&read_errors(IN, $date);
	close(IN);
	foreach $intf (keys %intf) {
	    if (defined($iftype{$intf, $date})) { # Have data for date
		$wk_inerr_10_hrs{$intf} += $inerr_10_hrs{$intf, $date};
		$wk_inerr_01_hrs{$intf} += $inerr_01_hrs{$intf, $date};
		$wk_inerr_001_hrs{$intf}+= $inerr_001_hrs{$intf, $date};
		$wk_inerrs{$intf} += $inerrs{$intf, $date};
		$max_wk_inerrs{$intf} = &max($inerrs{$intf, $date},
					     $max_wk_inerrs{$intf});
		$wk_ignores{$intf} += $ignores{$intf, $date};
		$max_wk_ignores{$intf} = &max($ignores{$intf, $date},
					      $max_wk_ignores{$intf});
		$wk_resets{$intf} += $resets{$intf, $date};
		$max_wk_resets{$intf} = &max($resets{$intf, $date},
					     $max_wk_resets{$intf});
		$wk_discards{$intf} += $discards{$intf, $date};
		$max_wk_discards{$intf} = &max($discards{$intf, $date},
					       $max_wk_discards{$intf});
		$peak_wk_discards{$intf} = &max($pk_discards{$intf, $date},
						$peak_wk_discards{$intf});

		$type{$intf} = $iftype{$intf, $date}; # use last value
	    }
	}
	undef(%intf);
	undef(%inerr_10_hrs);
	undef(%inerr_01_hrs);
	undef(%inerr_001_hrs);
	undef(%inerrs);
	undef(%ignores);
	undef(%resets);
	undef(%discards);
	undef(%iftype);
    }
}    

sub report_traffic {
    my($out) = @_;

#   printf($out "%-49s%-8s%8s%-4s\n",
#	   "", "Busy day", "", "Week");
#   printf($out "%-21s %11s %9s %7s  %7s  %7s  %6s\n",
#	   "Interface", "Peak sample", "Busy hour", "input", "output",
#	   "average", "speed");
#   printf($out "%-25s %3s %3s  %3s %3s  %3s %3s  %3s %3s  %3s %3s  %6s  %s\n",
#	   "", "%in", "out", "%in", "out", "%", "day", "%", "day",
#	   "%in", "out", "kbit/s", "iftype");

    foreach $intf (keys %counts) {
	printf($out
	       "%-25s %3d %3d  %3d %3d  %3d %3s  %3d %3s  %3d %3d  %6d  %-3d" .
	       "  %3d  %3d\n",
	       $intf,
	       $peak_in{$intf},
	       $peak_out{$intf},
	       $busy_in{$intf},
	       $busy_out{$intf},
	       $busy_ave_in{$intf},
	       &wday($busy_day_in{$intf}),
	       $busy_ave_out{$intf},
	       &wday($busy_day_out{$intf}),
	       $sum_in{$intf} / $counts{$intf},
	       $sum_out{$intf} / $counts{$intf},
	       $speed{$intf},
	       $type{$intf},
	       &percentile(50, @{ $in_90percs{$intf} }),
	       &percentile(50, @{ $out_90percs{$intf}})
	       );
    }
}

sub report_traffic_kbit {
    my($out) = @_;

#   printf($out "%-25s %13s  %13s  %13s  %13s %6s\n",
#	  "Interface", "Peak sample", "Busy hour", "Busy day(24h)",
#	   "Week average", "speed");
#   printf($out "%-25s %6s %6s  %6s %6s  %6s %6s  %6s %6s %6s %6s\n",
#	   "", "input", "output", "input", "output", "input", "output",
#	   "input", "output", "kbit/s", "iftype");

    foreach $intf(keys %counts_kbit) {
	printf($out "%-25s %6d %6d  %6d %6d  %6d %6d  %6d %6d %6d %6d" .
	       "  %6d %6d\n",
	       $intf,
	       $peak_kbit_in{$intf},
	       $peak_kbit_out{$intf},
	       $busy_kbit_in{$intf},
	       $busy_kbit_out{$intf},
	       $busy_ave_kbit_in{$intf},
	       $busy_ave_kbit_out{$intf},
	       $sum_in_kbit{$intf} / $counts_kbit{$intf},
	       $sum_out_kbit{$intf} / $counts_kbit{$intf},
	       $speed{$intf},
	       $type{$intf},
	       &percentile(50, @{ $in_90p_kbits{$intf} }),
	       &percentile(50, @{ $out_90p_kbits{$intf}})
	       );
    }
}

sub report_errors {
    my($out) = @_;

    foreach $intf(keys %wk_inerr_10_hrs) {
	printf($out
	"%-25s %3d %3d %3d  %4s %4s  %4s %4s  %5d %5d  %4s %4s %4s %d\n",
	       $intf,
	       $wk_inerr_10_hrs{$intf},
	       $wk_inerr_01_hrs{$intf},
	       $wk_inerr_001_hrs{$intf},
	       &nice_sprint_perc_4($max_wk_inerrs{$intf}),
	       &nice_sprint_perc_4($wk_inerrs{$intf}/7),
	       &nice_sprint_perc_4($max_wk_ignores{$intf}),
	       &nice_sprint_perc_4($wk_ignores{$intf}/7),
	       $wk_resets{$intf}/7,
	       $max_wk_resets{$intf},
	       &nice_sprint_perc_4($peak_wk_discards{$intf}),
	       &nice_sprint_perc_4($max_wk_discards{$intf}),
	       &nice_sprint_perc_4($wk_discards{$intf}/7),
	       $type{$intf}
	       );
    }
}


sub all_reports {
    my($week, $year) = @_;
    my($base_tm, $date, $date_str);
    my($repdir);

    $repdir = &week_report_dir_create($week, $year);

    open(OUT, sprintf(">%s/traffic", $repdir)) || return undef;
    &report_traffic(OUT);
    close(OUT);

    open(OUT, sprintf(">%s/traffic.kbit", $repdir)) || return undef;
    &report_traffic_kbit(OUT);
    close(OUT);

    open(OUT, sprintf(">%s/errors.perc", $repdir)) || return undef;
    &report_errors(OUT);
    close(OUT);
}

sub usage {
    
    printf(STDERR "usage: report-week.pl [[-w ww [-y yyyy]] | date]\n");
    printf(STDERR "       where date is either dd, mm-dd or yyyy-mm-dd\n");
    printf(STDERR "       and ww is week number and yyyy is year.\n");
    printf(STDERR "       No args makes report for previous week.\n");
    printf(STDERR "Report will be for previos week relative to \"date\"\n");
    printf(STDERR "if \"date\" is given otherwise the data for the\n");
    printf(STDERR "given week will be procssed and reported.\n");
    exit(1);
}


# Main

&getopts("hw:y:");

if (defined($opt_h)) {
    &usage();
    exit(1);
}

if (defined($opt_w)) {
    $week = $opt_w;
    if (defined($opt_y)) {
	$year = $opt_y;
    } else {
	$year = 1900 + (localtime(time))[5];
    }
} elsif ($#ARGV != 0) {
    if ($#ARGV == -1) {
	$date = &today();
	($week, $year) = &date_to_previous_week($date);
    } else {
	&usage();
    }
} else {
    $date_str = $ARGV[0];
    if ($date = &get_date($date_str)) {
	($week, $year) = &date_to_previous_week($date);
    }
}

&get_all_data($week, $year);
&all_reports($week, $year);
