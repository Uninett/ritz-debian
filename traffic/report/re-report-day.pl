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

#
# Script to re-process the data for a given interface
#
# Input: day in either of forms (dd / mm-dd / yyyy-mm-dd)
#        base of file name (router.ip.ad.re.ss)
# Output: appended to files in report/yyyy-mm/dd/*.
#
# Output format is the same as produced by report-day.pl.

push(@INC, "%LIBDIR%");

require 'read-hr-log.pl';
require 'db-lookup.pl';
require 'search.pl';
require 'date.pl';

sub process_file_data {
    local($name) = @_;
    local($h, $errpct, $inpkts);

    push(@names, $name);

    $ifspeed{$name} = $ifspeed;
    $iftype{$name} = $iftype;

    foreach $i (0 .. 23) {
	$h = sprintf("%02d", $i);
	foreach $v ("ifInOctets", "ifOutOctets",
		    "ifInNUcastPkts", "ifInUcastPkts",
		    "ifOutNUcastPkts", "ifOutUcastPkts",
		    "ifInDiscards", "ifOutDiscards",
		    "ifInErrors", "ifOutErrors",
		    "locIfInRunts", "locIfInCRC",
		    "locIfInFrame", "locIfInOverrun",
		    "locIfInIgnored", "locIfInAbort",
		    "locIfResets", "locIfRestarts",
		    "locIfCollisions") # Should this list be read from cf file?
	{
	    if (defined $count{$v,$h}) {
		if (!defined($total{$name,$v})) {
		    $total{$name,$v} = 0;
		}
		$total{$name,$v} += $count{$v,$h};
		if (!defined($max_r{$name,$v}) ||
		    $max_r{$name,$v} < $count{$v,$h})
		{
		    $max_r{$name,$v} = $count{$v,$h};
		    $max_h{$name,$v} = $i;
		}
	    }
	}
	foreach $v ("ifInOctets", "ifOutOctets") {
	    if (!defined($peak_r{$name,$v}) ||
		$peak_r{$name,$v} < $max_rate{$v,$h})
	    {
		$peak_r{$name,$v} = $max_rate{$v,$h};
		$peak_h{$name,$v} = $i;
	    }
	}
	$inpkts = 0;
	if (defined($count{"ifInUcastPkts",$h})) {
	    $inpkts += $count{"ifInUcastPkts",$h};
	}
	if (defined($count{"ifInNUcastPkts",$h})) {
	    $inpkts += $count{"ifInNUcastPkts",$h};
	}
	if ($inpkts > 0) {
	    $errpct = $count{"ifInErrors",$h}*100.0/$inpkts;
	    if ($errpct > 1.0) {
		$errhrs{$name,"1.0"}++;
	    }
	    if ($errpct > 0.1) {
		$errhrs{$name,"0.1"}++;
	    }
	    if ($errpct > 0.01) {
		$errhrs{$name,"0.01"}++;
	    }
	}
    }
    undef %max_rate;
    undef %count;
}

sub report_traffic {
    local($out) = @_;

#    printf("%-20s %15s  %15s\n", "", "Busy hour", "Busy sample");
#    printf("%-20s %7s %7s  %7s %7s  %7s  %6s\n",
#	   "LineName", "input", "output",
#	   "input", "output", "average", "speed");
#    printf("%-20s %3s  %2s %3s  %2s  %3s  %2s %3s  %2s  %3s %3s  %6s  %6s",
#	   "", "%", "hr", "%", "hr",
#	   "%", "hr", "%", "hr", "%in", "out", "kbit/s", "iftype");
#    printf("\n");

    foreach $n (@names) {
	if ($ifspeed{$n} != 0) {
	    printf($out "%-20s %3d  %02d %3d  %02d",
		   $n,
		   $max_r{$n,"ifInOctets"}*8*100.0/3600/$ifspeed{$n},
		   $max_h{$n,"ifInOctets"},
		   $max_r{$n,"ifOutOctets"}*8*100.0/3600/$ifspeed{$n},
		   $max_h{$n,"ifOutOctets"});
	    printf($out "  %3d  %02d %3d  %02d  %3d %3d  %6d  %6d\n",
		   $peak_r{$n,"ifInOctets"}*8*100.0/$ifspeed{$n},
		   $peak_h{$n,"ifInOctets"},
		   $peak_r{$n,"ifOutOctets"}*8*100.0/$ifspeed{$n},
		   $peak_h{$n,"ifOutOctets"},
		   $total{$n,"ifInOctets"}*8*100.0/3600/24/$ifspeed{$n},
		   $total{$n,"ifOutOctets"}*8*100.0/3600/24/$ifspeed{$n},
		   $ifspeed{$n}/1000,
		   $iftype{$n});
	}
    }
}

sub report_traffic_kbit {
    local($out) = @_;

#    printf($out "%-20s %13s  %13s  %13s %6s\n",
#	   "", "Busy hour", "Busy sample", "24hr average", "speed");
#    printf($out "%-20s %6s %6s  %6s %6s  %6s %6s %6s %6s\n",
#	   "Interface", "input", "output", "input", "output",
#	   "input", "output", "kbit/s", "iftype");

    foreach $n (@names) {
	if ($ifspeed{$n} != 0) {
	    printf($out "%-20s %6d %6d  %6d %6d  %6d %6d %6d %6d\n",
		   $n,
		   $max_r{$n,"ifInOctets"}*8/1000/3600,
		   $max_r{$n,"ifOutOctets"}*8/1000/3600,
		   $peak_r{$n,"ifInOctets"}*8/1000,
		   $peak_r{$n,"ifOutOctets"}*8/1000,
		   $total{$n,"ifInOctets"}*8/1000/3600/24,
		   $total{$n,"ifOutOctets"}*8/1000/3600/24,
		   $ifspeed{$n}/1000,
		   $iftype{$n});
	}
    }
}

sub nice_sprint_perc_4 {
    local($v) = @_;

    if ($v >= 10) {
	return sprintf("%4.1f", $v);
    }
    return sprintf("%4.2f", $v);
}

sub nice_sprint_perc_5 {
    local($v) = @_;

    if ($v >= 10) {
	return sprintf("%5.2f", $v);
    }
    return sprintf("%5.3f", $v);
}


sub report_error_percs {
    local($out) = @_;
    local($val);
    local($inpkts);
    local($outpkts);

    foreach $n (@names) {
	printf ($out "%-20s   %2d  %2d  %2d",
		$n,
		$errhrs{$n,"1.0"},
		$errhrs{$n,"0.1"},
		$errhrs{$n,"0.01"});
	$inpkts = ($total{$n,"ifInNUcastPkts"} +
		   $total{$n,"ifInUcastPkts"});
	foreach $v ("ifInErrors", "locIfInCRC", "locIfInFrame",
		    "locIfInAbort", "locIfInIgnored")
	{
	    if ($inpkts > 0) {
		$val = $total{$n,$v}*100.0/$inpkts;
	    } else {
		$val = 0;
	    }
	    printf ($out " %4s", &nice_sprint_perc_4($val));
	}
	printf ($out "  %5d", $total{$n,"locIfResets"});
	$outpkts = ($total{$n,"ifOutNUcastPkts"} +
		    $total{$n,"ifOutUcastPkts"});
	if ($outpkts > 0) {
	    $val = $total{$n,"ifOutDiscards"}*100.0/$outpkts;
	} else {
	    $val = 0;
	}
	printf ($out " %5s", &nice_sprint_perc_5($val));
	printf ($out " %6d\n", $iftype{$n});
    }
}

sub report_ether_perc_errs {
    local($out) = @_;
    local($inpkts, $outpkts);
    
    foreach $n (@names) {
	if ($iftype{$n} != 6 &&	# ethernet-csmacd
	    $iftype{$n} != 7)	# iso88023-csmacd
	{
	    next;
	}
	printf ($out "%-20s ", $n);
	$inpkts = ($total{$n,"ifInNUcastPkts"} +
		   $total{$n,"ifInUcastPkts"});
	foreach $v ("ifInErrors", "locIfInCRC", "locIfInFrame",
		    "locIfInRunt", "locIfInGiants", "locIfInIgnored")
	{
	    if ($inpkts > 0) {
		$val = $total{$n,$v}*100.0/$inpkts;
	    } else {
		$val = 0;
	    }
	    printf ($out " %5s", &nice_sprint_perc_5($val));
	}
	printf($out " ");
	$outpkts = ($total{$n,"ifOutNUcastPkts"} +
		    $total{$n,"ifOutUcastPkts"});
	foreach $v ("ifOutErrors", "ifOutDiscards", "locIfCollisions") {
	    if ($outpkts > 0) {
		$val = $total{$n,$v}*100.0/$outpkts;
	    } else {
		$val = 0;
	    }
	    printf ($out " %5s", &nice_sprint_perc_5($val));
	}
	printf ($out "\n");
    }
}

sub get_file_data {
    local($date, $base) = @_;
    local($cat, $file);
    local($name);

    if (!defined ($name = &file_to_name($base, $date))) {
	printf(STDERR "Could not find 'logical name' for $base / $date\n");
	return undef;
    }
    ($cat, $file) = &find_cat_and_file($base, $date);
    open(IN, "$cat $file |") || die "$cat $file | $!\n";
    &read_log(IN);
    close(IN);

    &process_file_data($name);
}


# Append to all the daily reports

sub all_reports {
    local($date) = @_;
    local($repdir);

    $repdir = &report_dir_create($date);

    open (OUT, sprintf(">>%s/traffic", $repdir)) || return undef;
    &report_traffic(OUT);
    close (OUT);
    
    open (OUT, sprintf(">>%s/traffic.kbit", $repdir)) || return undef;
    &report_traffic_kbit(OUT);
    close (OUT);

    open (OUT, sprintf(">>%s/errors.perc", $repdir)) || return undef;
    &report_error_percs(OUT);
    close (OUT);

    open (OUT, sprintf(">>%s/ether_errs.perc", $repdir)) || return undef;
    &report_ether_perc_errs(OUT);
    close (OUT);
    
}

sub usage {

    printf(STDERR "usage: re-report-day.pl date base-of-file-name\n");
    printf(STDERR "       where date is either dd, mm-dd or yyyy-mm-dd\n");
    printf(STDERR "       and base-of-file-name is router.ip.ad.re.ss\n");
    printf(STDERR "       or router.#n\n");
    exit(1);
}

require 'getopts.pl';

# Main

if ($#ARGV != 1) {
    &usage();
}

$date_str = $ARGV[0];
if ($date = &get_date($date_str)) {
    $base = $ARGV[1];
    &get_file_data($date, $base);
    &all_reports($date);
} else {
    &usage();
}
