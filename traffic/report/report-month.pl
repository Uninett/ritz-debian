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

# Produce reports for a month's worth of traffic
#
# Usage: report-week.pl [-m month [-y year]]
#   default is previous month
#
# Output in several files in report/monthly/yyyy/mm/*.
# Files:
#   traffic		%-wise traffic report
#   traffic.kbit	kbit/s-wise traffic report
#
# Possible heading for traffic:
#
# Interface        Peak         Busy day     Month
#                  sample    input   output  average  speeds
#                 in% out    % day    % day  %in out  kbit/s  ift
#xxxxxxxxxxxxxxxx xxx xxx  xxx  xx  xxx  xx  xxx xxx  xxxxxx  xxx
#
# Possible heading for traffic.kbit:
#
# Interface
#            Peak sample        Busy day        Month average       speeds
#           input output  input day output day   input output  ift  kbit/s
#xxxxxxxxx xxxxxx xxxxxx xxxxxx  xx xxxxxx  xx  xxxxxx xxxxxx  xxx  xxxxxx
#

push(@INC, "%LIBDIR%");

require 'getopts.pl';
require 'date.pl';
require 'search.pl';
require 'read-day-report.pl';
require 'utils.pl';

# Suck in and post-process data

sub get_all_data {
    my($datespec) = @_;
    my($base_tm, $tm, $date, $dn, $speed, $intf, %lastspeed);

    ($base_tm, $ndays) = &decode_datespec($datespec);
    foreach $d (1 .. $ndays) {
	$tm = $base_tm + ($d - 1) * (60*60*24);
	$date = &tm_to_date($tm);
	$dn = &find_day_report_dir(&tm_to_datespec($tm, "day"));
	open(IN, $dn . "/traffic") || next;
#	printf("Reading traffic for date %s\n", $date);
	&read_traffic(IN, $date);
	close(IN);
	foreach $intf (keys %intf) {
	    if (defined($iftype{$intf, $date})) { # have data for date
		if ($average_load_in{$intf, $date} > $busy_in{$intf}) {
		    $busy_in{$intf} = $average_load_in{$intf, $date};
		    $busy_day_in{$intf} = $d;
		}
		if ($average_load_out{$intf, $date} > $busy_out{$intf}) {
		    $busy_out{$intf} = $average_load_out{$intf, $date};
		    $busy_day_out{$intf} = $d;
		}
		$peak_in{$intf} =  &max($peak_load_in{$intf, $date},
					$peak_in{$intf});
		$peak_out{$intf} = &max($peak_load_out{$intf, $date},
					$peak_out{$intf});

		$sum_in{$intf} += $average_load_in{$intf, $date};
		$sum_out{$intf} += $average_load_out{$intf, $date};
		$counts{$intf}++;

		$type{$intf} = $iftype{$intf, $date}; # use last value
		$speed = $ifspeed{$intf, $date}; # use last value

		if (!defined $lastspeed{$intf}) {
		    $lastspeed{$intf} = $speed;
		    $speeds{$intf} = sprintf("%6d", $speed);
		} else {
		    if ($lastspeed{$intf} != $speed) {
			$lastspeed{$intf} = $speed;
			$speeds{$intf} .= sprintf("/%d", $speed);
		    }
		}
	    }
	}

	undef(%intf);
	undef(%busy_load_in);
	undef(%busy_load_out);
	undef(%peak_load_in);
	undef(%peak_load_out);
	undef(%average_load_in);
	undef(%average_load_out);
	undef(%iftype);

	open(IN, $dn . "/traffic.kbit") || next;
#	printf("Reading traffic.kbit for date %s\n", $date);
	&read_traffic_kbit(IN, $date);
	close(IN);
	foreach $intf (keys %intf) {
	    if (defined($iftype{$intf, $date})) { # Have data for date
		if ($average_load_in{$intf, $date} > $busy_kbit_in{$intf}) {
		    $busy_kbit_in{$intf} = $average_load_in{$intf, $date};
		    $busy_kbit_day_in{$intf} = $d;
		}
		if ($average_load_out{$intf, $date} > $busy_kbit_out{$intf}) {
		    $busy_kbit_out{$intf} = $average_load_out{$intf, $date};
		    $busy_kbit_day_out{$intf} = $d;
		}
		if ($peak_load_in{$intf, $date} > $peak_kbit_in{$intf}) {
		    $peak_kbit_in{$intf} = $peak_load_in{$intf, $date};
		}
		if ($peak_load_out{$intf, $date} > $peak_kbit_out{$intf}) {
		    $peak_kbit_out{$intf} = $peak_load_out{$intf, $date};
		}

		$sum_in_kbit{$intf} += $average_load_in{$intf, $date};
		$sum_out_kbit{$intf} += $average_load_out{$intf, $date};
		$counts_kbit{$intf}++;
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
    }
}

sub report_traffic {
    my($out, $nd) = @_;

    foreach $intf (keys %counts) {
	printf($out "%-25.25s %3d %3d  %3d %3d  %3d %3d  %3d %3d  %s %d\n",
	       $intf,
	       $peak_in{$intf},
	       $peak_out{$intf},
	       $busy_in{$intf},
	       $busy_day_in{$intf},
	       $busy_out{$intf},
	       $busy_day_out{$intf},
	       $sum_in{$intf} / $nd,
	       $sum_out{$intf} / $nd,
	       $speeds{$intf},
	       $type{$intf},
	       );
    }
}

sub report_traffic_kbit {
    my($out, $nd) = @_;

    foreach $intf (keys %counts_kbit) {
	printf($out "%-25.25s %6d %6d  %6d %3d %6d %3d  %6d %6d  %s %d\n",
	       $intf,
	       $peak_kbit_in{$intf},
	       $peak_kbit_out{$intf},
	       $busy_kbit_in{$intf},
	       $busy_kbit_day_in{$intf},
	       $busy_kbit_out{$intf},
	       $busy_kbit_day_out{$intf},
	       $sum_in_kbit{$intf} / $nd,
	       $sum_out_kbit{$intf} / $nd,
	       $speeds{$intf},
	       $type{$intf},
	       );
    }
}

sub all_reports {
    my($dsp) = @_;
    my($base_tm, $nd, $date, $date_str);
    my($repdir, $f);

    ($base_tm, $nd) = &decode_datespec($dsp);
    $repdir = &month_report_dir_create($dsp);

    $f = sprintf("%s/traffic", $repdir);
    open(OUT, ">$f") || die "Could not open $f for write: $!\n";
    &report_traffic(OUT, $nd);
    close(OUT);

    $f = sprintf("%s/traffic.kbit", $repdir);
    open(OUT, ">$f") || die "Could not open $f for write: $!\n";
    &report_traffic_kbit(OUT, $nd);
    close(OUT);
}

sub usage {

    printf(STDERR "usage: report-month.pl [-m mm [-y yyyy]]\n");
    printf(STDERR "default is last month.\n");
    exit(1);
}

#
# Main
#

&Getopts("m:y:");

if (defined($opt_m)) {
    if (defined($opt_y)) {
	$ds = &make_datespec("month", $opt_y . "-" . $opt_m);
    } else {
	$ds = &make_datespec("month", $opt_m);
    }
} else {
    $ds = &make_datespec("month");
}

&get_all_data($ds);
&all_reports($ds);
