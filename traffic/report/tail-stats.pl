#!%PERL%
#
# $Id$
#

# Copyright (c) 2003
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
# 3. Neither the name of UNINETT or NORDUnet nor the names
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

push(@INC, "%LIBDIR%");
push(@INC, "%CONFDIR%");

require 'getopts.pl';

require "date.pl";
require "search.pl";
require "db-lookup.pl";
require "utils.pl";
require "read-raw-log.pl";

require "config.pl";

use Data::Dumper;
use File::Basename;
use Fcntl qw(:seek);
use Date::Parse;
use Date::Format;

use strict;
no strict "vars";


$retention_time = 3600;		# 1 hour


sub save_file {
    my($b) = @_;
    our($DATATREE);

    return $DATATREE . "/tail-save/" . $b . ".pl";
}

sub restore_vars {
    my($b) = @_;
    my($p);
    our($fd);

    if (!defined($fd->{$b})) {
	my $f = &save_file($b);
	if (open(IN, $f)) {
	    my @lines = <IN>;
	    close(IN);
	    my $var_settings = join("", @lines);
	    eval $var_settings;
	    $fd->{$b} = $p;
	}
    }

    if (defined($p)) {
	# Set up to read tail of log
	foreach my $v (keys %{ $p->{"base"} }) {
	    $base{$v} = $p->{"base"}->{$v};
	    $sample_time{$v,-1} = $p->{"last_sample"};
	}
	$date = $p->{"date_string"};
	$ifspeed = $p->{"ifspeed"};
	$iftype = $p->{"iftype"};
	$ifdescr = $p->{"ifdescr"};
    }
}

sub save_vars {
    my($b) = @_;
    my($p) = $fd->{$b};
    our(%count, %base, %sample_time);
    our($date, $ifspeed, $iftype, $ifdescr, $max_sample);
    
    foreach my $v (keys %base) {
	$p->{"base"}->{$v} = $base{$v};
    }
    $p->{"date_string"} = $date;
    $p->{"ifspeed"} = $ifspeed;
    $p->{"iftype"} = $iftype;
    $p->{"ifdescr"} = $ifdescr;
    $p->{"last_sample"} = $sample_time{$max_sample};
    $p->{"date"} = &today();

    my $f = &save_file($b);
    open(OUT, ">" . $f . ".new");
    print OUT Data::Dumper->Dump([$p], ["p"]);
    close(OUT);
    rename($f . ".new", $f);

    undef %count;
    undef %base;
    undef %sample_time;
    undef $date;
    undef $ifspeed;
    undef $iftype;
    undef $ifdescr;
    undef $max_sample;
}

sub convert_time {
    my($t, $ss) = @_;

    if (!defined($ss)) {
	$ss = &date_to_tm(&today());
    }
    return $ss + 3600.0 * $t;
}

sub convert_times {
    my($times, $start, $end) = @_;
    my($s, $i);
    our(%sample_time, %base);
    our(%sample_secs, $max_sample);
    our($opt_d);
    my($start_secs);

    # Handle the stupidity that the time scale is in hours
    # for the "current day", and handle rollover at midnight
    if(defined($sample_time{$start-1})) {
	$s = $start-1;
    } else {
	$s = $start;
    }
    for($i = $s; $sample_time{$i} > $sample_time{$max_sample}; $i++) {
	$sample_time{$i} -= 24;
	foreach my $k (keys %base) {
	    $sample_time{$k,$i} -= 24;
	}
    }

    if(defined($opt_d)) {
	$start_secs = str2time($opt_d);
    } else {
	$start_secs = &date_to_tm(&today());
    }

    for($i = $s; $i <= $end; $i++) {
	my $secs = &convert_time($sample_time{$i}, $start_secs);
	if ($i != $s) {
	    push(@$times, $secs);
	}
	$sample_secs{$i} = $secs;
    }
}

sub compute_basic_values {
    my($b, $d, $start, $end) = @_;
    my($i);
    our($max_sample, %count);
    our(%sample_secs);

    for ($i = $start; $i <= $end; $i++) {
	if (!defined($sample_secs{$i-1})) {
	    next;
	}
	$delta_t = $sample_secs{$i} - $sample_secs{$i-1};

	foreach my $k (keys %$d) {
	    my($ap) = $d->{$k}->{"values"};
	    my(@vars) = @{ $d->{$k}->{"vars"} };
	    my($mult) = $d->{$k}->{"mult"};

	    my($v) = 0;
	    foreach my $var (@vars) {
		$v += $count{$var,$i};
	    }
	    my($val) = $v * $mult / $delta_t;
	    push(@$ap, $val);
	}
    }
}

sub average {
    my($ap) = @_;
    my($n) = 0;
    my($sum) = 0;

    foreach my $val (@$ap) {
	$n++;
	$sum += $val;
    }

    if ($n == 0) { return undef; }

    return $sum / $n;
}

sub variance {
    my($ap) = @_;
    my($sumsq) = 0;
    my($avg);
    my($n) = 0;

    $avg = &average($ap);
    foreach my $val (@$ap) {
	$n++;
	$sumsq += $val * $val;
    }
    if ($n <= 1) { return undef; }

    return ($sumsq - ($n * $avg * $avg)) / ($n - 1);
}

sub stddev {
    my($ap) = @_;
    
    if ($#$ap == 0) { return undef; }
    my($var) = &variance($ap);

    if ($var < 0) { return undef; }

    return sqrt($var);
}

sub exp_decay {
    my($accum, $new, $perc) = @_;

    # This is slightly dubious, since it'll give more initial weight
    # to the first samples.
    if ($accum == 0) {
	return $new;
    } else {
	return ($accum * (100 - $perc) + $new * $perc) / 100.0;
    }
}

sub accumulate_stats {
    my($cv, $fp) = @_;
    my($stp, $asp);
    our($opt_p);

    if(!defined($fp->{"stats"})) {
	$fp->{"stats"} = {};
    }
    $stp = $fp->{"stats"};
    if(!defined($stp->{$cv})) {
	$stp->{$cv} = {};
    }
    $asp = $stp->{$cv};

    my $ap = $fp->{"save_values"}->{$cv};
    if (!defined($ap)) {
	return;
    }

    $asp->{"average"} = &average($ap);
    $asp->{"stddev"} = &stddev($ap);

    $asp->{"accum_average"} =
	&exp_decay($asp->{"accum_average"}, $asp->{"average"}, $opt_p);
    $asp->{"accum_stddev"} =
	&exp_decay($asp->{"accum_stddev"}, $asp->{"stddev"}, $opt_p);
}

sub flag_deviations {
    my($cv, $b, $fp, $dp) = @_;
    my($i);
    our($opt_l, $opt_u, $opt_i);
    my($report) = "";

    my($aavg) = $fp->{"stats"}->{$cv}->{"accum_average"};
    my($astdd)= $fp->{"stats"}->{$cv}->{"accum_stddev"};

    if (!defined($aavg) || !defined($astdd)) {
	return;
    }
    my($vp) = $dp->{$cv}->{"values"};
    my($tp) = $dp->{"sample_times"}->{"values"};
    my($dhp) = $fp->{"deviations"};
    if (!defined($dhp)) {
	$fp->{"deviations"} = {};
    }
    $dhp = $fp->{"deviations"};

    my($up_thresh) = $opt_u * $astdd;
    my($down_tresh) = $opt_l * $astdd;
    my($name) = &file_to_name($b, &today);
    if (!defined($name) && defined($opt_i)) {
	return "";
    }

    for($i = 0; $i <= $#$vp; $i++) {
	my $delta = abs($$vp[$i] - $aavg);
	# Test needs to be improved
	if ($delta > $up_thresh &&
	    $aavg > 1000 &&
	    $$vp[$i] != 0
	    )
	{
	    if (!$dhp->{$cv}) {
		$report .=
		    sprintf("%s %s %5s dev: cur %d avg %d stdd %d * %s\n",
			    time2str("%d %h %T", $$tp[$i]),
			    &file_to_name($b, &today),
			    $cv,
			    $$vp[$i],
			    $aavg,
			    $astdd,
			    $astdd != 0 ?
				sprintf("%4.2f", $delta / $astdd) :
				"undef"
			    );
	    }
	    $dhp->{$cv} = 1;
	} else {
	    if ($delta < $down_tresh) {
		if ($dhp->{$cv}) {
		    $report .=
			sprintf("%s %s %5s clearing deviation\n",
			       time2str("%d %h %T", $$tp[$i]),
			       &file_to_name($b, &today),
			       $cv);
		    $report .=
			sprintf("%s %s %5s values: cur %d avg %d stdd %d\n",
			       time2str("%d %h %T", $$tp[$i]),
			       &file_to_name($b, &today),
			       $cv,
			       $$vp[$i],
			       $aavg,
			       $astdd);
		}
		$dhp->{$cv} = 0;
	    }
	}
    }
    return $report;
}

sub mail_report {
    my($from, $to, $report) = @_;

    my $subj = "Stat deviations ";
    $subj .= time2str("%R", time);
    open(OUT, "| %RAWSENDMAIL%");
    printf(OUT "From: %s\n", $from);
    printf(OUT "To: %s\n", $to);
    printf(OUT "Subject: %s\n", $subj);
    printf(OUT "\n");
    printf(OUT "%s\n", $report);
    close(OUT);
}


# At this point, saved values are somewhere below $fd, and the current
# set of samples is in $d.  The last values have not yet been
# incorporated in the saved values.

sub process_values {
    my($b, $d) = @_;
    my($i, $report);
    our($fd, $opt_m, $stat_report);

    if (!defined($fd->{$b})) {
	$fd->{$b} = {};
    }

    foreach $cv ("okbps", "ikbps", "ipps", "opps", "obpp", "ibpp") {
	&accumulate_stats($cv, $fd->{$b});
	$report = &flag_deviations($cv, $b, $fd->{$b}, $d);
	if ($report ne "") {
	    if (defined($opt_m)) {
		$stat_report .= $report;
	    } else {
		printf(STDOUT $report);
	    }
	}
    }
}

sub save_data {
    my($b, $d) = @_;
    our($fd);
    my($stp) = $d->{"sample_times"}->{"values"};
    my($save_ap, $ap);

    my($sp) = $fd->{$b}->{"save_values"};
    if (!defined($sp)) {
	$fd->{$b}->{"save_values"} = {};
	$sp = $fd->{$b}->{"save_values"};
    }

    # save all computed values
    while ($#$stp != -1) {
	foreach my $k (keys %$d) {
	    $save_ap = $sp->{$k};
	    if (!defined($save_ap)) {
		$sp->{$k} = [];
		$save_ap = $sp->{$k};
	    }
	    $ap = $d->{$k}->{"values"};
	    push(@$save_ap, $$ap[0]);
	    shift(@$ap);
	}
    }
}

sub trim_data {
    my($b, $time_threshold) = @_;
    our($fd);

    my($sp) = $fd->{$b}->{"save_values"};
    if (!defined($sp)) { return; }

    # Trim out samples older than $time_treshold
    $stp = $sp->{"sample_times"};
    while (defined($$stp[0]) && $$stp[0] < $time_threshold) {
	foreach my $k (keys %$sp) {
	    my($ap) = $sp->{$k};
	    shift(@$ap);
	}
    }
}


sub process_data {
    my($b, $start, $end) = @_;
    my($i);
    my(@in_kbps, @out_kbps, @in_pps, @out_pps);
    my(@ibpp, @obpp, @times);
    my($iov, $oov);
    my($p) = $fd->{$b};
    our(%sample_secs);

    # Prefer 64-bit counters
    if (defined($p->{"base"}->{"ifHCInOctets"})) {
	$iov = "ifHCInOctets";
	$oov = "ifHCOutOctets";
    } else {
	$iov = "ifInOctets";
	$oov = "ifOutOctets";
    }

    &convert_times(\@times, $start, $end);

    my($desc) = {
	"ikbps" => {
	    "values" => \@in_kbps,
	    "vars" => [ $iov ],
	    "mult" => 8.0 / 1000.0,
	},
	"okbps" => {
	    "values" => \@out_kbps,
	    "vars" => [ $oov ],
	    "mult" => 8.0 / 1000.0,
	},
	"ipps" => {
	    "values" => \@in_pps,
	    "vars" => [ "ifInNUcastPkts", "ifInUcastPkts" ],
	    "mult" => 1,
	},
	"opps" => {
	    "values" => \@out_pps,
	    "vars" => [ "ifOutNUcastPkts", "ifOutUcastPkts" ],
	    "mult" => 1,
	},
    };

    &compute_basic_values($b, $desc, $start, $end);

    # bytes per packet derived from values computed above.

    my($delta) = $end - $start;
    my($eoa) = $#{ $desc->{"ipps"}->{"values"} };

    for ($i = $eoa - $delta; $i <= $eoa; $i++) {
	my($ipps) = $desc->{"ipps"}->{"values"}[$i];
	my($opps) = $desc->{"opps"}->{"values"}[$i];
	if (!defined($ipps) || $ipps == 0) {
	    push(@ibpp, 0);
	} else {
	    push(@ibpp, $desc->{"ikbps"}->{"values"}[$i] * 1000 / 8.0
		 / $ipps);
	}
	if (!defined($opps) || $opps == 0) {
	    push(@obpp, 0);
	} else {
	    push(@obpp, $desc->{"okbps"}->{"values"}[$i] * 1000 / 8.0
		 / $opps);
	}
    }
    
    $desc->{"ibpp"}->{"values"} = \@ibpp;
    $desc->{"obpp"}->{"values"} = \@obpp;
    $desc->{"sample_times"}->{"values"} = \@times;

    &process_values($b, $desc);
    &save_data($b, $desc);
    undef %sample_secs;
}

sub position_file {
    my($fh, $b) = @_;
    my $p = $fd->{$b};

    my($mtime, $size) = (stat($fh))[9,7];
    my $mod_date = &tm_to_date($mtime);
    my $pos = $fd->{$b}->{"position"};

    if (!defined($pos) || $mod_date ne $p->{"date"} || $pos > $size) {
	# stale data and/or file was rotated out
	$fd->{$b}->{"position"} = 0;
	return undef;
    }
    return seek($fh, $pos, SEEK_SET);
}

sub save_position {
    my($fh, $b) = @_;
    our($fd);

    my $pos = tell($fh);
    $fd->{$b}->{"position"} = $pos;
}

sub report_tail_stats {
    my($rfile, $b, $ofile) = @_;
    our($fd, $opt_i);
    my($ikbps, $okbps, $n);
    my($sp) = $fd->{$b}->{"save_values"};
    my $ia = $sp->{"ikbps"};
    my $oa = $sp->{"okbps"};

    $n = 0;
    foreach my $v (@{ $ia }) {
	$n++;
	$ikbps += $v;
    }
    if ($n != 0) {
	$ikbps /= $n;
    } else {
	$ikbps = 0;
    }

    $n = 0;
    foreach my $v (@{ $oa }) {
	$n++;
	$okbps += $v;
    }
    if ($n != 0) {
	$okbps /= $n;
    } else {
	$okbps = 0;
    }

    my $name = &file_to_name($b, &today);
    if (!defined($name)) {
	if (defined($opt_i)) {	# ignore unnamed logical ports
	    next;
	}
	$name = $b;
    }
    # Output: name   last-kbps-in last-kbps-out avg-kbps-in avg-kbps-out
    printf($rfile "%-30s %8d %8d %8d %8d %8d\n",
	   $name,
	   $ia->[$#$ia],
	   $oa->[$#$oa],
	   $ikbps, $okbps,
	   $fd->{$b}->{"ifspeed"} / 1000,
	   );
}

sub tail_process_file {
    my($rfile, $f) = @_;
    my($b) = basename($f);
    my($cat, $base) = &cat_and_base($f, &today());
    our($max_sample, $opt_r);

    if ($cat ne "cat") { return undef; }

    &restore_vars($b);

    open(IN, $f) || return undef;
    &position_file(\*IN, $b);
    &read_log(\*IN, 1);
    &save_position(\*IN, $b);
    close(IN);

    &process_data($b, 0, $max_sample);
    &trim_data($b, &timelocal(localtime) - $retention_time);
    &save_vars($b);
    if (defined($opt_r)) {
	&report_tail_stats($rfile, $b, $opt_r);
    }
}

# Read in data for one logical port and portion it up for the
# processing routines elsewhere in this file.

sub do_one_file {
    my($dsp, $name) = @_;
    my($i);
    our($max_sample, %sample_time, $fd, %base, $date);
    my($d) = &get_date($dsp);

    my($b) = &name_to_file($name, $d);
    if (! defined($b)) {
	die "Could not find file name for $name / $d\n";
    }

    my($cat, $f) = &find_cat_and_file($b, $d);
    if (! defined($f)) {
	die "Could not find data file for $base / $d\n";
    }

    open(DAYLOG, "$cat $f |") ||
	die "Could not open \"$cat $f\": $!\n";
    &read_log(\*DAYLOG);
    close(DAYLOG);
    
    # for type of octet counter detection in process_data()
    foreach my $v (keys %base) {
	$fd->{$b}->{"base"}->{$v} = $base{$v};
    }

    my($t0) = str2time($date);

    # set up to process 1/2 hour at a time
    my($samples_per_go) = int($max_sample / (24 * 2));

    for($i = 0; $i < $max_sample; $i += $samples_per_go) {
	my $top = &min($i + $samples_per_go - 1, $max_sample);

	&process_data($b, $i, $top);
	&trim_data($b, (&convert_time($sample_time{$top}, $t0) -
			$retention_time));
    }
}

sub do_all_files {
    my($dir) = &find_data_dir(&today());
    my(@files) = &directory_files($dir);
    our($stat_report);
    our($opt_m, $opt_M, $opt_r);

#    select(STDOUT); $| = 1;	# unbuffer
    $stat_report = "";
    if (defined($opt_r)) {
	unlink($opt_r) || die "Could not unlink $opt_r";
    }
    open(REP, ">" . $opt_r) || die "Could not open $opt_r for write";

    foreach $f (@files) {
	&tail_process_file(\*REP, $dir . "/" . $f);
#	printf(".");
    }
    close(REP);
    if ($stat_report != "" && defined($opt_m) && defined($opt_M)) {
	&mail_report($opt_M, $opt_m, $stat_report);
    }
#    printf("\n");
}

sub usage {

    printf(STDERR "usage: tail-stats [-n name] [-d datestr] [-u up-limit]\n");
    printf(STDERR "    [-l low-limit] [-p percent] [-r outfile] [-i]\n");
    printf(STDERR "    [-m mailto -M mailfrom]\n");
    printf(STDERR "\n");
    printf(STDERR "Option descriptions:\n");
    printf(STDERR "-n name      logical name of port to be analyzed\n");
    printf(STDERR "             (default is all logical ports, but see -i)\n");
    printf(STDERR "-d datestr   date which should be analyzed\n");
    printf(STDERR "             (default is current day, ");
    printf(STDERR "start from end of last run)\n");
    printf(STDERR "-u up-limit  factor on an up-transition for flagging\n");
    printf(STDERR "-l low-limit factor to go below when de-flagging\n");
    printf(STDERR "-p percent   how many percent should data from new");
    printf(STDERR " interval count\n");
    printf(STDERR "-r outfile   produce report about current load\n");
    printf(STDERR "             only applicable when doing current day\n");
    printf(STDERR "-i           ignore unnamed logical ports when");
    printf(STDERR " making report\n");
    printf(STDERR "-m mailto    mail statistical deviations report to addr\n");
    printf(STDERR "-M mailfrom  set from address for stat dev. reports\n");

    exit 1;
}

#
# Main
#

&Getopts("d:hil:M:m:n:p:r:u:");

# -n name	logical name of port to be analyzed
# -d datestr	date which should be analyzed
# -u up-limit	factor on an up-transition when flagging a deviation
# -l low-limit	factor to pass when de-flagging a deviation
# -p percent	how many percent should data from new interval
#		influence averaged statistical values (avg, stddev)
# -r outfile	produce report about current load to this file
#		only applicable if doing all files of current day
# -i		ignore unnamed logical ports when making report
# -m mailto	address to mail stats deviations report to

if (defined($opt_h)) {
    &usage();
}
if (defined($opt_n) && !defined($opt_d)) {
    printf(STDERR "Must specify both -n and -d value\n");
    &usage();
}
if (defined($opt_d) && !defined($opt_n)) {
    printf(STDERR "Must specify both -n and -d value\n");
    &usage();
}
if (defined($opt_m) && !defined($opt_M)) {
    printf(STDERR "Must specify both -m and -M values\n");
    &usage();
}
if (defined($opt_M) && !defined($opt_m)) {
    printf(STDERR "Must specify both -m and -M values\n");
    &usage();
}

if (!defined($opt_u)) {
    $opt_u = 18;
}
if (!defined($opt_l)) {
    $opt_l = 5;
}
if (!defined($opt_p)) {
    $opt_p = 20;
}

if (defined($opt_d) && defined($opt_n)) {
    if (defined($opt_r)) {
	printf(STDERR "-r cannot be used while procesing old stats\n");
	&usage();
    }
    &do_one_file($opt_d, $opt_n);
} else {
    &do_all_files();
}
