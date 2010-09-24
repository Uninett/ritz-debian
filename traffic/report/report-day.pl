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

# Produce reports for the day's traffic
#
# Input: day in either of forms (dd / mm-dd / yyyy-mm-dd)
# Output in several files in report/yyyy-mm/dd/*.
# Files: 
#   traffic		Traffic report (busy hour, peak, average, in percent)
#   traffic.kbit	Traffic report (busy hour, peak, average, in kbit/s)
#   ether_errs
#   errors
# Files contain only data, no headings.
#
# 
# Possible heading for traffic:
#
#             Busy hour      Busy sample
# Intf.   input  output    input  output  average   speed          90%  90%
#         %  hr   %  hr    %  hr   %  hr  %in out  kbit/s  iftype   in  out
#xxxxxx xxx  xx xxx  xx  xxx  xx xxx  xx  xxx xxx  xxxxxx  xxxxxx  xxx  xxx
#
# Possible heading for traffic.kbit
#
#          Busy hour    Busy sample   24hr average  speed            90%    90%
# Intf.  input output   input output   input output kbit/s iftype     in    out
#xxxxxx xxxxxx xxxxxx  xxxxxx xxxxxx  xxxxxx xxxxxx xxxxxx xxxxxx xxxxxx xxxxxx
#
# Possible heading for errors:
#
# Interface   inerr hrs >x% --------- in % ---------  -- out -----peak-
#               1.0 0.1 .01 Errs  CRC  Frm Abrt  Ign  Reset Disc% Disc% iftype
#xxxxxxxxxxxxx   xx  xx  xx xxxx xxxx xxxx xxxx xxxx  xxxxx xxxxx xxxxx xxxxxx
#
# Possible heading for ether_errs:
#
# Interface           --------------  in % --------------  ----- out % -----
#                      Errs   CRC Frame Runts Giant Ignor   Errs  Disc Colls
#xxxxxxxxxxxxxxxxxxx  xxxxx xxxxx xxxxx xxxxx xxxxx xxxxx  xxxxx xxxxx xxxxx


push(@INC, "%LIBDIR%");

require 'read-hr-log.pl';
require 'db-lookup.pl';
require 'search.pl';
require 'date.pl';
require 'utils.pl';

use strict;

sub get_file_data {
    my($date, $dir, $cat, $f, $name) = @_;
    my($h, $errpct, $inpkts, $outpk, $discpct);
    my($tm);
    my($IN);
    our($iov, $oov);
    our(%ifspeed, %iftype);
    our($ifspeed, $iftype, %sample_delta, %sample_time, %count);
    our(%total, %max_r, %max_h, %peak_r, %peak_h);
    our(%errhrs, %max_rate, %peak_disc_pct);
    our($in_90perc_bps, $out_90perc_bps);

    $tm = &date_to_tm($date);

# Purposefully make $iov and $oov globals.

    open ($IN, "$cat $dir/$f |") || return undef;
    &read_log($IN, $tm);
    close($IN);
    
    $iov = &octets_var("in");
    $oov = &octets_var("out");

    $ifspeed{$name} = $ifspeed;
    $iftype{$name} = $iftype;

    foreach my $i (0 .. 23) {
	$h = sprintf("%02d", $i);
	foreach my $v ($iov, $oov,
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
	foreach my $v ($iov, $oov) {
	    if (!defined($peak_r{$name,$v}) ||
		$peak_r{$name,$v} < $max_rate{$v,$h})
	    {
		$peak_r{$name,$v} = $max_rate{$v,$h};
		$peak_h{$name,$v} = $i;
	    }
	}
	$inpkts = ($count{"ifInUcastPkts",$h} +
		   $count{"ifInNUcastPkts",$h} +
		   $count{"ifInErrors",$h}); # need to include these also...
	if (!defined($errhrs{$name,"1.0"})) {
	    $errhrs{$name,"1.0"} = 0;
	}
	if (!defined($errhrs{$name,"0.1"})) {
	    $errhrs{$name,"0.1"} = 0;
	}
	if (!defined($errhrs{$name,"0.01"})) {
	    $errhrs{$name,"0.01"} = 0;
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
	$outpk = ($count{"ifOutUcastPkts",$h} +
		  $count{"ifOutNUcastPkts",$h} +
		  $count{"ifOutDiscards",$h}); # need to include these also...
	if ($outpk > 0) {
	    $discpct = $count{"ifOutDiscards",$h}*100.0/$outpk;
	    if (!defined($peak_disc_pct{$name}) ||
		$peak_disc_pct{$name} < $discpct)
	    {
		$peak_disc_pct{$name} = $discpct;
	    }
	}
    }
    $in_90perc_bps  = &percentile(90, &sample_val_ps($iov)) * 8.0;
    $out_90perc_bps = &percentile(90, &sample_val_ps($oov)) * 8.0;

    undef %max_rate;
    undef %count;
    undef %sample_delta;
    undef %sample_time;
}


sub undef_file_data {

    our(%ifspeed, %iftype, %total, %max_r, %max_h);
    our(%peak_r, %peak_h, %errhrs, %peak_disc_pct);

    undef %ifspeed;
    undef %iftype;
    undef %total;
    undef %max_r;
    undef %max_h;
    undef %peak_r;
    undef %peak_h;
    undef %errhrs;
    undef %peak_disc_pct;

    our(%count, %max_rate, %sample_delta, %sample_time, $max_sample);
    
    undef %count;
    undef %max_rate;
    undef %sample_delta;
    undef %sample_time;
    undef $max_sample;
}


sub report_one_port {
    my($n) = @_;
    our($TOUT, $TKOUT, $EPOUT, $EEOUT);

    &report_traffic($TOUT, $n);
    &report_traffic_kbit($TKOUT, $n);
    &report_error_percs($EPOUT, $n);
    &report_ether_perc_errs($EEOUT, $n);
}


sub do_one_file {
    my($dir, $f, $date) = @_;
    my($cat, $base) = &cat_and_base($f);
    my($name);
    
    if (!defined ($name = &file_to_name($base, $date))) {
	return undef;
    }
    &get_file_data($date, $dir, $cat, $f, $name);
    &report_one_port($name);
    &undef_file_data();
}


sub do_all_files {
    my($date) = @_;
    my($dir);
    my(@files);

    if (!defined ($dir = &find_data_dir($date))) {
	printf(STDERR "No data found for date $date\n");
	exit(1);
    }
    @files = &directory_files($dir);
    foreach my $f (@files) {
	&do_one_file($dir, $f, $date);
    }
}

sub sprint_percent {
    my($val) = @_;

    if ($val >= 10) {
	return sprintf("%3d", $val);
    } elsif ($val >= 1) {
	return sprintf("%3.1f", $val);
    } elsif ($val < 1) {
	return substr(sprintf("%4.2f", $val), 1);
    }

}

sub report_traffic {
    my($out, $n) = @_;
    our(%ifspeed, %max_r, %peak_r, %total, %iftype);
    our(%peak_h, %max_h, $iov, $oov);
    our($in_90perc_bps, $out_90perc_bps);

#    printf("%-20s %15s  %15s\n", "", "Busy hour", "Busy sample");
#    printf("%-20s %7s %7s  %7s %7s  %7s  %6s  %3s  %3s\n",
#	 "Interface", "input", "output",
#	 "input", "output", "average", "speed", "90%", "90%");
#    printf("%-20s %3s  %2s %3s  %2s  %3s  %2s %3s  %2s  %3s %3s  %6s  %6s  %3d  %3d",
#	 "", "%", "hr", "%", "hr",
#	 "%", "hr", "%", "hr", "%in", "out", "kbit/s", "iftype", "in", "out");
#    printf("\n");

    if ($ifspeed{$n} != 0) {
	printf($out "%-20s %3s  %02d %3s  %02d",
	       $n,
	       &sprint_percent($max_r{$n,$iov}*8*100.0/3600/$ifspeed{$n}),
	       $max_h{$n,$iov},
	       &sprint_percent($max_r{$n,$oov}*8*100.0/3600/$ifspeed{$n}),
	       $max_h{$n,$oov});
	printf($out "  %3s  %02d %3s  %02d  %3s %3s  %6d  %6d  %3s  %3s\n",
	       &sprint_percent($peak_r{$n,$iov}*8*100.0/$ifspeed{$n}),
	       $peak_h{$n,$iov},
	       &sprint_percent($peak_r{$n,$oov}*8*100.0/$ifspeed{$n}),
	       $peak_h{$n,$oov},
	       &sprint_percent($total{$n,$iov}*8*100.0/3600/24/$ifspeed{$n}),
	       &sprint_percent($total{$n,$oov}*8*100.0/3600/24/$ifspeed{$n}),
	       $ifspeed{$n}/1000,
	       $iftype{$n},
	       &sprint_percent($in_90perc_bps * 100.0 / $ifspeed{$n}),
	       &sprint_percent($out_90perc_bps * 100.0 / $ifspeed{$n})
	       );
    }
}

sub report_traffic_kbit {
    my($out, $n) = @_;
    our(%ifspeed, %max_r, %peak_r, %total, %iftype);
    our($in_90perc_bps, $out_90perc_bps, $iov, $oov);

#    printf($out "%-20s %13s  %13s  %13s %6s\n",
#	   "", "Busy hour", "Busy sample", "24hr average", "speed");
#    printf($out "%-20s %6s %6s  %6s %6s  %6s %6s %6s %6s %6s %6s\n",
#	   "Interface", "input", "output", "input", "output",
#	   "input", "output", "kbit/s", "iftype", "90%in", "90%out");

    if ($ifspeed{$n} != 0) {
	printf($out "%-20s %6d %6d  %6d %6d  %6d %6d %6d %6d %6d %6d\n",
	       $n,
	       $max_r{$n,$iov}*8/1000/3600,
	       $max_r{$n,$oov}*8/1000/3600,
	       $peak_r{$n,$iov}*8/1000,
	       $peak_r{$n,$oov}*8/1000,
	       $total{$n,$iov}*8/1000/3600/24,
	       $total{$n,$oov}*8/1000/3600/24,
	       $ifspeed{$n}/1000,
	       $iftype{$n},
	       $in_90perc_bps / 1000,
	       $out_90perc_bps / 1000);
    }
}


sub report_error_percs {
    my($out, $n) = @_;
    my($val);
    my($inpkts,$tot_in);
    my($outpkts,$tot_out);

    our(%errhrs, %total, %iftype, %peak_disc_pct);


    printf($out "%-20s   %2d  %2d  %2d",
	   $n,
	   $errhrs{$n,"1.0"},
	   $errhrs{$n,"0.1"},
	   $errhrs{$n,"0.01"});
    $inpkts = ($total{$n,"ifInNUcastPkts"} +
	       $total{$n,"ifInUcastPkts"});
    $tot_in = $inpkts + $total{$n,"ifInErrors"};
    foreach my $v ("ifInErrors", "locIfInCRC", "locIfInFrame",
		"locIfInAbort", "locIfInIgnored")
    {
	if ($tot_in > 0) {
	    $val = $total{$n,$v}*100.0/$tot_in;
	} else {
	    $val = 0;
	}
	printf ($out " %5s", &nice_sprint_perc_5($val));
    }
    printf($out "  %5d", $total{$n,"locIfResets"});
    $outpkts = ($total{$n,"ifOutNUcastPkts"} +
		$total{$n,"ifOutUcastPkts"});
    $tot_out = $outpkts + $total{$n,"ifOutDiscards"};
    if ($tot_out > 0) {
	$val = $total{$n,"ifOutDiscards"}*100.0/$tot_out;
    } else {
	$val = 0;
    }
    printf($out " %5s", &nice_sprint_perc_5($val));
    printf($out " %5s", &nice_sprint_perc_5($peak_disc_pct{$n}));
    printf($out " %6d\n", $iftype{$n});
}

sub report_ether_perc_errs {
    my($out, $n) = @_;
    my($inpkts, $outpkts, $val);
    our(%iftype, %total);


    if ($iftype{$n} != 6 &&	# ethernet-csmacd
	$iftype{$n} != 7)	# iso88023-csmacd
    {
	return;
    }
    printf($out "%-20s ", $n);
    $inpkts = ($total{$n,"ifInNUcastPkts"} +
	       $total{$n,"ifInUcastPkts"} +
	       $total{$n,"ifInErrors"}); # need these also
    foreach my $v ("ifInErrors", "locIfInCRC", "locIfInFrame",
		"locIfInRunt", "locIfInGiants", "locIfInIgnored")
    {
	if ($inpkts > 0) {
	    if (defined($total{$n,$v})) {
		$val = $total{$n,$v}*100.0/$inpkts;
	    } else {
		$val = 0;
	    }
	} else {
	    $val = 0;
	}
	printf($out " %5s", &nice_sprint_perc_5($val));
    }
    printf($out " ");
    $outpkts = ($total{$n,"ifOutNUcastPkts"} +
		$total{$n,"ifOutUcastPkts"});
    foreach my $v ("ifOutErrors", "ifOutDiscards", "locIfCollisions") {
	if ($outpkts > 0) {
	    $val = $total{$n,$v}*100.0/($outpkts + $total{$n,$v});
	} else {
	    $val = 0;
	}
	printf($out " %5s", &nice_sprint_perc_5($val));
    }
    printf($out "\n");
}


sub open_reports {
    my($date) = @_;
    my($repdir);
    our($opt_t);
    our($TOUT, $TKOUT, $EPOUT, $EEOUT);

    $repdir = &report_dir_create($date);

    my $p = defined($opt_t) ? ">" : "";

    open($TOUT,  sprintf($p . ">%s/traffic", $repdir)) || return undef;
    open($TKOUT, sprintf($p . ">%s/traffic.kbit", $repdir)) || return undef;
    open($EPOUT, sprintf($p . ">%s/errors.perc", $repdir)) || return undef;
    open($EEOUT, sprintf($p . ">%s/ether_errs.perc", $repdir)) || return undef;
}

sub close_reports {
    my($date) = @_;
    our($TOUT, $TKOUT, $EPOUT, $EEOUT);

    close($TOUT);
    close($TKOUT);
    close($EPOUT);
    close($EEOUT);
}


sub usage {

    printf(STDERR "usage: report-day.pl date\n");
    printf(STDERR "       where date is either dd, mm-dd or yyyy-mm-dd\n");
    exit(1);
}

require 'getopts.pl';

# Main

&Getopts("s:d:t");

our($opt_t);

my $date_str = $ARGV[0];
my $date = &get_date($date_str);

shift @ARGV;

if (defined($opt_t)) {
    &open_reports($date);
    my $dir = &find_data_dir($date);
    foreach my $f (@ARGV) {
	&do_one_file($dir, $f, $date);
    }
    &close_reports($date);
    exit(0);
}

if (defined($date)) {
    &open_reports($date);
    &do_all_files($date);
    &close_reports($date);
}
