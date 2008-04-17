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

# Produce reports showing the "load spectrum" for a month's
# worth of traffic.
#
# Parameters: [-d datespec]
#   Generate reports for month and year of datespec
#   (year defaults to current year, month to previous month)
#
# Output in files in report/monthly/yyyy/mm/:
#   spectre-in.total	input load report for all hours of all days
#   spectre-in.work	input load report for all hours in all work-days 08-16
#   spectre-out.total	output load report for all hours of all days
#   spectre-out.work	output load report for all hours in all work-days 08-16
#
#
# Possible heading for spectre-{in,out}.total:
#
#           Average                                            
#           load, %                        % of hours load > n%        Speed(s)
# Port name  in out  90  80  70  60  50  40  30  20  10   5   3 IfType kbit/s
# xxxxxxxxx
#
# Possible heading for spectre-{in,out}.work:
#
#           Average
#           load, %          % of hours 08-16 Mon-Fri load > n%        Speed(s)
# Port name  in out  90  80  70  60  50  40  30  20  10   5   3 ifType kbit/s
# xxxxxxxxx
#
# NOTE: Port name coloumns should be 25 chars, this will push the
# rightmost coloumn over 80.
#

push(@INC, "%LIBDIR%");

require 'getopts.pl';
require 'date.pl';
require 'search.pl';
require 'read-hr-log.pl';
require 'utils.pl';
require 'db-lookup.pl';

# suck in and post-process data

# Get data from a single raw data file

sub get_file_data {
    local($d, $f, $date, $wday) = @_;
    local($base, $cat);
    local($name, $h, $i);
    local($load);
    local($workhour);
    
    if ($f =~ /^(.*).gz$/) {
	$cat = "%GZCAT%";
	$base = $1;
    } elsif ($f =~ /^(.*).Z$/) {
	$cat = "%ZCAT%";
	$base = $1;
    } else {
	$cat = "/bin/cat";
	$base = $f;
    }
    if (!defined ($name = &file_to_name($base, $date))) {
	return undef;
    }

    my($tm) = &date_to_tm($d);

    open (in, "$cat $d/$f |") || return undef;
    &read_log (in, $tm);
    close(in);

    if ($ifspeed == 0) {
	return undef;
    }
    $names{$name} = 1;

    if (!defined $ifspeed{$name}) {
	$ifspeed{$name} = $ifspeed;
	$speeds{$name} = sprintf("%6d", $ifspeed / 1000);
    } else {
	if ($ifspeed{$name} != $ifspeed) {
	    $ifspeed{$name} = $ifspeed;
	    $speeds{$name} .= sprintf("/%d", $ifspeed / 1000);
	}
    }

    $iftype{$name} = $iftype;
    
    foreach $i (0 .. 23) {
	$h = sprintf("%02d", $i);
	foreach $v ("ifInOctets", "ifOutOctets") {
	    if (defined $count{$v,$h}) {
		$load = $count{$v,$h}*8*100.0/3600/$ifspeed;

		$num_hours{$v,$name}++;
		$sum_load{$v,$name} += $load;

		$workhour = 0;
		if (($i >= 8) && ($i < 16) &&
		    ($wday ne "Sat") && ($wday ne "Sun"))
		{
		    $num_work_hours{$v,$name}++;
		    $sum_work_load{$v,$name} += $load;
		    $workhour = 1;
		}

		foreach $limit (3, 5, 10, 20, 30, 40, 50, 60, 70, 80, 90) {
		    if ($load > $limit) {
			$hours{$v,$limit,$name}++;
			if ($workhour) {
			    $work_hours{$v,$limit,$name}++;
			}
		    } else {
			last;
		    }
		}
	    }
	}
    }
    undef %count;
    undef %max_rate;
}


# Get data for all files for all days in given month

sub get_all_data {
    local($datespec) = @_;
    local($base_tm, $days, $tm, $date, $wday);
    local($base, $catter, $f);
    local($dir, @files);
    local($i);

    ($base_tm, $days) = &decode_date_spec($datespec);

    foreach $d (0 .. $days - 1) {
	$tm = $base_tm + ($d * (60*60*24));
	$date = &tm_to_date($tm);
	$wday = &tm_to_day_of_week($tm);
	
	if (!defined ($dir = &find_data_dir($date))) {
	    printf (STDERR "No data found for date $date\n");
	    next;
	}
	@files = &directory_files($dir);
	$i = 0;
	foreach $f (@files) {
	    $i++;
	    if (defined $opt_r) {
		if ($f !~ /$opt_r/) {
		    if ($opt_v) {
			printf(STDERR "Skipping for date %s: %s\n",
			       $date, $f);
		    }
		    next;
		}
	    }
	    if ($opt_v) {
		printf(STDERR "Processing %3d of %3d for date %s: %s\n",
		       $i, $#files + 1, $date, $f);
	    };
	    &get_file_data($dir, $f, $date, $wday);
	}
    }
}

sub total_report {
    local($out, $var) = @_;
    local($speed1, $rest);

    foreach $port (keys %names) {
	printf($out "%-25.25s ", $port);
	foreach $v ("ifInOctets", "ifOutOctets") {
	    if ($num_hours{$v,$port} == 0) {
		if ($opt_v) {
		    printf (STDERR "num_hours{$v,$port} == 0\n");
		}
		printf ($out "%3d ", 0);
	    } else {
		printf($out "%3d ",
		       $sum_load{$v,$port} /
		       $num_hours{$v,$port});
	    }
	}
	printf($out " ");

	foreach $limit (90, 80, 70, 60, 50, 40, 30, 20, 10, 5, 3) {
	    if ($num_hours{$var,$port} == 0) {
		printf ($out "%3d ", 0);
	    } else {
		printf($out "%3d ",
		       $hours{$var,$limit,$port} * 100.0 /
		       $num_hours{$var,$port});
	    }
	}
	printf($out "%6d ", $iftype{$port});

	($speed1, $rest) = split(/\//, $speeds{$port}, 2);
	printf($out "%6d", $speed1);
	if (defined $rest) {
	    printf($out "/%s", $rest);
	}
	printf($out "\n");
    }
}

# Create report for workays / workhours (Mon - Fri 08-16)

sub work_report {
    local($out, $var) = @_;
    local($speed1, $rest);

    foreach $port (keys %names) {
	printf($out "%-25.25s ", $port);
	foreach $v ("ifInOctets", "ifOutOctets") {
	    if ($num_work_hours{$v,$port} == 0) {
		if ($opt_v) {
		    printf (STDERR "num_work_hours{$v,$port} == 0\n");
		}
		printf ($out "%3d ", 0);
	    } else {
		printf($out "%3d ",
		       $sum_work_load{$v,$port} /
		       $num_work_hours{$v,$port});
	    }
	}
	printf($out " ");

	foreach $limit (90, 80, 70, 60, 50, 40, 30, 20, 10, 5, 3) {

	    if ($num_work_hours{$var,$port} == 0) {
		printf ($out "%3d ", 0);
	    } else {
		printf($out "%3d ",
		       $work_hours{$var,$limit,$port} * 100.0 /
		       $num_work_hours{$var,$port});
	    }
	}
	printf($out "%6d ", $iftype{$port});

	($speed1, $rest) = split(/\//, $speeds{$port}, 2);
	printf($out "%6d", $speed1);
	if (defined $rest) {
	    printf($out "/%s", $rest);
	}
	printf($out "\n");
    }
}

# Create all reports

sub make_reports {
    local($datespec) = @_;
    local($dir);

    $dir = &month_report_dir_create($datespec);

    open (out, ">$dir/spectre-in.total");
    &total_report(out, "ifInOctets");
    close(out);

    open (out, ">$dir/spectre-out.total");
    &total_report(out, "ifOutOctets");
    close(out);

    open (out, ">$dir/spectre-in.work");
    &work_report(out, "ifInOctets");
    close(out);

    open (out, ">$dir/spectre-out.work");
    &work_report(out, "ifOutOctets");
    close(out);
}

sub usage {

    printf(STDERR
	   "usage: report-month-sp.pl [-d datespec] [-r regexp] [-v]\n");
    printf(STDERR
	   "where datespec should specify a month ([yy[yy]]-mm),\n");
    printf(STDERR
	   "regexp limits the files processed and -v is verbose switch\n");
    exit(1);
}

#
# Main
#

# Options:
#  -d datespec	month to process data for
#  -r regexp	limit files processed to those matching regexp
#  -v		verbose (progress report)

&Getopts("d:r:v");

if ($#ARGV != -1) {
    &usage();
}

if (defined $opt_d) {
    $datespec = $opt_d;
    ($tm, $ndays) = &decode_date_spec($datespec);
    if ($ndays < 28 || $ndays > 31) {
	&usage();
    }
} else {
    $datespec = &make_datespec("month"); # second arg missing, "undef" (?)
}

&get_all_data($datespec);
&make_reports($datespec);

