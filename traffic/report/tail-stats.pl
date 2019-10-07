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

use Getopt::Std;

require "date.pl";
require "search.pl";
require "db-lookup.pl";
require "utils.pl";
require "read-raw-log.pl";

require "zino-config.pl";

use Data::Dumper;
use File::Basename;
use Fcntl qw(:seek);
use Date::Parse;
use Date::Format;

use RRDs;

use strict;


our($retention_time) = 3600;		# 1 hour


sub save_file {
    my($b) = @_;
    our($DATATREE);

    return $DATATREE . "/tail-save/" . $b . ".pl";
}

sub restore_vars {
    my($b) = @_;
    my($p);
    our($fd);
    our(%base, %lasttime, %sample_time, %dstcomp);
    our($date, $ifspeed, $iftype, $ifdescr);

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
	no strict 'refs';

	# Set up to read tail of log
	foreach my $a ("base", "lasttime", "dstcomp") {
	    foreach my $v (keys %{ $p->{$a} }) {
		$$a{$v} = $p->{$a}->{$v};
	    }
	}
	$sample_time{-1} = $p->{"last_sample"};
	$date = $p->{"date_string"};
	$ifspeed = $p->{"ifspeed"};
	$iftype = $p->{"iftype"};
	$ifdescr = $p->{"ifdescr"};
    }
}

sub save_vars {
    my($b) = @_;
    our($fd);
    my($p) = $fd->{$b};
    our(%count, %base, %sample_time);
    our($date, $ifspeed, $iftype, $ifdescr, $max_sample);
    our(%lasttime, %dstcomp);
    
    no strict 'refs';

    foreach my $a ("base", "lasttime", "dstcomp") {
	foreach my $v (keys %$a) {
	    $p->{$a}->{$v} = $$a{$v};
	}
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
    undef %lasttime;
    undef %dstcomp;
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
    my($times, $start, $end, $tm) = @_;
    my($s, $i);
    our(%sample_time, %base);
    our(%sample_secs, $max_sample);
    our($opt_d, $debug);
    my($start_secs);

    # Handle that the time scale is in hours for the "current day",
    # and handle rollover at midnight
    if(defined($sample_time{$start-1})) {
	$s = $start-1;
    } else {
	$s = $start;
    }
    if ($debug) {
	printf(STDERR "convert_times: starting from %d\n", $s);
	foreach my $i (sort { $a <=> $b } keys %sample_time) {
	    printf(STDERR "convert_times: sample_time{%s} = %s\n",
		   $i, $sample_time{$i});
	}
    }

    for($i = $s; $sample_time{$i} > $sample_time{$max_sample}; $i++) {
	$sample_time{$i} -= 24;
	foreach my $k (keys %base) {
	    $sample_time{$k,$i} -= 24;
	}
    }

    if(defined($tm)) {
	$start_secs = $tm;
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
    if ($debug) {
	foreach my $k (keys %sample_secs) {
	    printf(STDERR "convert_times: sample_secs{%s} = %s\n",
		   $k, $sample_secs{$k});
	}
    }
}

sub compute_basic_values {
    my($b, $d, $start, $end) = @_;
    my($i, $delta_t);
    our($max_sample, %count);
    our(%sample_secs);
    our($ifspeed, $opt_D);

    my $n = &file_to_name($b, &today);

    for ($i = $start; $i <= $end; $i++) {
	if (!defined($sample_secs{$i-1})) {
	    if (defined($opt_D) && $opt_D eq $n) {
		printf(STDERR "For %s, sample_secs ix %d nonexistent\n",
		       $n, $i-1);
	    }
	    next;
	}
	$delta_t = $sample_secs{$i} - $sample_secs{$i-1};

	if (defined($opt_D) && $opt_D eq $n) {
	    printf(STDERR "Delta for step %d is %d secs, (%d vs %d)\n",
		   $i, $delta_t, $sample_secs{$i}, $sample_secs{$i-1});
	}
	if ($delta_t == 0) {
	    printf(STDERR "Delta for step %d is zero! Name %s base %s\n",
		   $i, $n, $b);
	    next;
	}

	foreach my $k (keys %$d) {
	    my($ap) = $d->{$k}->{"values"};
	    my(@vars) = @{ $d->{$k}->{"vars"} };
	    my($mult) = $d->{$k}->{"mult"};

	    my($v) = 0;
	    my($ov) = 0;
	    my($vn);
	    foreach my $var (@vars) {
		$v += $count{$var,$i};
		$vn = $var;
		if ($var =~ /Octets/o) {
		    $ov = 1;
		}
	    }
	    my($val) = $v * $mult / $delta_t;

	    if (defined($opt_D) && $opt_D eq $n) {
		printf(STDERR "Computed %s step %d value %s\n",
		       $k, $i, $val);
	    }

	    # If processing an octet counter, check that we're
	    # within ifSpeed's range, balk otherwise and set sample to zero.
	    if ($ov && $ifspeed != 0) {
		my($br) = $val * 1000.0;
		if ($br > $ifspeed * 1.05) { # Allow 5% overshoot
		    printf(STDERR
			   "ERROR: Bitrate exceeds ifSpeed for %s:\n" .
			   " %s vs\n" .
			   " %s\n" .
			   "at time %s, var %s, sample ignored\n",
			   $b, $br, $ifspeed, $sample_secs{$i}, $vn);
		    $val = 0;
		}
	    }

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
    my($cv, $b, $fp, $dp, $tm) = @_;
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
    my($name);
    if (defined($tm)) {
	$name = &file_to_name($b, &tm_to_date($tm));
    } else {
	$name = &file_to_name($b, &today);
    }
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
			    $name,
			    $cv,
			    $$vp[$i],
			    $aavg,
			    $astdd,
			    $astdd > 1e-100 ? # cheesy random value
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
				$name,
				$cv);
		    $report .=
			sprintf("%s %s %5s values: cur %d avg %d stdd %d\n",
				time2str("%d %h %T", $$tp[$i]),
				$name,
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
    $subj .= time2str("%R", $^T);
    open(OUT, "| %RAWSENDMAIL% -t");
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
    my($b, $d, $tm) = @_;
    my($i, $report);
    our($fd, $opt_m, $stat_report, $opt_N);

    if (!defined($fd->{$b})) {
	$fd->{$b} = {};
    }

    foreach my $cv ("okbps", "ikbps", "ipps", "opps", "obpp", "ibpp") {
	&accumulate_stats($cv, $fd->{$b});
	if (!defined($opt_N)) {
	    $report = &flag_deviations($cv, $b, $fd->{$b}, $d, $tm);
	    if ($report ne "") {
		if (defined($opt_m)) {
		    $stat_report .= $report;
		} else {
		    printf(STDOUT $report);
		}
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

    # Trim out samples older than $time_threshold
    my $stp = $sp->{"sample_times"};
    while (defined($$stp[0]) && $$stp[0] < $time_threshold) {
	foreach my $k (keys %$sp) {
	    my($ap) = $sp->{$k};
	    shift(@$ap);
	}
    }
}


sub process_data {
    my($b, $start, $end, $tm) = @_;
    my($i);
    my(@in_kbps, @out_kbps, @in_pps, @out_pps);
    my(@ibpp, @obpp, @times);
    my($iov, $oov);
    our($fd);
    my($p) = $fd->{$b};
    our(%sample_secs, $opt_R, $debug);

    # Prefer 64-bit counters
    if (defined($p->{"base"}->{"ifHCInOctets"})) {
	$iov = "ifHCInOctets";
	$oov = "ifHCOutOctets";
    } else {
	$iov = "ifInOctets";
	$oov = "ifOutOctets";
    }

    my $n = &file_to_name($b, &today);
    our($opt_D);
#    if (defined($opt_D) && $opt_D eq $n) {
#	$debug = 1;
#    }

    &convert_times(\@times, $start, $end, $tm);

#    $debug = 0;

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

    $desc->{"sample_times"}->{"values"} = \@times;

    # This used only in-kbps, out-kbps and sample times
    # so do this now before we destroy the values in $desc
    if (defined($opt_R)) {
	&update_rrd($b, $desc, $tm);
    }

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

    &process_values($b, $desc, $tm);
    &save_data($b, $desc);
    undef %sample_secs;
}

sub create_rrd {
    my($n) = @_;
    my($cmd);
    my(@cmd);
    our($opt_V);

    # 3 years (and then some) in the past as starting point
    my($s) = $^T - (4 * 365) * 24 * 3600;


    push(@cmd, sprintf("%s.rrd", $n));

    push(@cmd, "-b");
    push(@cmd, sprintf("%d", $s));

    push(@cmd, "-s");
    push(@cmd, "300");

    push(@cmd, "DS:In:GAUGE:600:0:U");
    push(@cmd, "DS:Out:GAUGE:600:0:U");
    # 72 hours of 5-minute intervals
    push(@cmd, "RRA:AVERAGE:0.5:1:864");
    # 21 days of 30-minute intervals
    push(@cmd, "RRA:AVERAGE:0.5:6:1008");
    # 62 days of 2-hour intervals
    push(@cmd, "RRA:AVERAGE:0.5:24:744");
    # 1095 days (3 years) of 24-hour intervals
    push(@cmd, "RRA:AVERAGE:0.5:288:730");
    # And similar for the max values:
    push(@cmd, "RRA:MAX:0.5:1:864");
    push(@cmd, "RRA:MAX:0.5:6:1008");
    push(@cmd, "RRA:MAX:0.5:24:744");
    push(@cmd, "RRA:MAX:0.5:288:730");

    if ($opt_V) {
	printf(STDERR "RRDs::create %s\n", join("\n", @cmd));
    }
    RRDs::create(@cmd);
    if (RRDs::error) {
	printf(STDERR "RRDs::create failed: %s\n", RRDs::error);
	return undef;
    }
    return 1;
}

sub update_rrd {
    my($b, $d, $tm) = @_;
    my($i);
    our($opt_V, $opt_D);
    my($name);

    if (defined($tm)) {
	$name = &file_to_name($b, &tm_to_date($tm));
    } else {
	$name = &file_to_name($b, &today);
    }
    if (!defined($name)) { return; }
    if (-f $name . ".lock") { return; }
    if (! -f $name . ".rrd") {
	&create_rrd($name) || return;
    }

    my($eoa) = $#{ $d->{"sample_times"}->{"values"} };
    my($tap) = $d->{"sample_times"}->{"values"};
    my($iap) = $d->{"ikbps"}->{"values"};
    my($oap) = $d->{"okbps"}->{"values"};
    my(@args);
    my($lastupdate, $n_skip, $n_done, $n_oos, $firstskip, $prev_t);

    $n_skip = $n_done = $n_oos = $prev_t = 0;

    push(@args, sprintf("%s.rrd", $name));
    $lastupdate = RRDs::last($args[0]);

    for ($i = 0; $i <= $eoa; $i++) {
	if ($tap->[$i] > $lastupdate) {
	    if ($tap->[$i] > $prev_t) {
		push(@args, sprintf("%d:%f:%f", 
				    $tap->[$i],
				    $iap->[$i] * 1000.0,
				    $oap->[$i] * 1000.0));
		$prev_t = $tap->[$i];
		$n_done++;
	    } else {
		$n_oos++;
	    }
	} else {
	    if (!defined($firstskip)) {
		$firstskip = $tap->[$i];
	    }
	    $n_skip++;
	}
    }
    if ($n_done != 0) {
	RRDs::update(@args);
	if (RRDs::error) {
	    printf(STDERR "RRDs::update %s -- error: %s\n",
		   join("\n", @args), RRDs::error);
	}
    }
    if ($n_skip != 0) {
	printf(STDERR "%s: RRDs skipped %d entries, did %d," .
	       " first skipped = %d, lastupdate = %d\n",
	       $name, $n_skip, $n_done, $firstskip, $lastupdate);
    }
    if ($n_oos != 0) {
	printf(STDERR "%s: RRDs skipped %d entries out of sequence, did %d\n",
	    $name, $n_oos, $n_done);
    }

    if ($opt_V ||
	(defined($opt_D) && $opt_D eq $name))
    {
	printf(STDERR "RRDs::update %s\n", join("\n", @args));
    }
}

sub time_str {
    my($t) = @_;
    my($s, $m, $h, $md, $mon, $y, $wd, $yd, $dst) = gmtime($t);

    return sprintf("%d-%02d-%02d %02d:%02d:%02d",
		   $y + 1900, $mon+1, $md,
		   $h, $m, $s);
}


sub position_file {
    my($fh, $b) = @_;
    our($fd, $opt_D);
    my $p = $fd->{$b};

    my($mtime, $size) = (stat($fh))[9,7];
    my $mod_date = &tm_to_date($mtime);
    my $pos = $fd->{$b}->{"position"};

    my $name = &file_to_name($b, &today);

    if (!defined($pos) || $pos > $size ||
	(($mod_date ne $p->{"date"}) &&
	 ($mod_date ne &yesterday() && !&just_past_midnight()))) {
	# stale data and/or file was rotated out
	$fd->{$b}->{"position"} = 0;
	if (defined($opt_D) && $opt_D eq $name) {
	    printf(STDERR "Positioning for %s to 0\n", $name);
	}
	return undef;
    }

    if (defined($opt_D) && $opt_D eq $name) {
	printf(STDERR "Positioning for %s to %d\n", $name, $pos);
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
    our($fd, $opt_i, $opt_V);
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
	    if (defined($opt_V)) {
		printf(STDERR "Skipping unnamed port for: %s\n", $b);
	    }
	    next;
	}
	$name = $b;
    }
    # Output:
    # name  last-kbps-in last-kbps-out avg-kbps-in avg-kbps-out ifspeed-in-kbps
    #
    # last-kbps-in    
    # last-kbps-out     last computed kbps value
    # avg-kbps-in     
    # avg-kbps-out      average over history we keep
    # ifspeed-in-kbps   interface speed in kbit/s
    printf($rfile "%-30s %8d %8d %8d %8d %8d\n",
	   $name,
	   $ia->[$#$ia],
	   $oa->[$#$oa],
	   $ikbps, $okbps,
	   $fd->{$b}->{"ifspeed"} / 1000,
	   );
}

sub tail_process_file {
    my($rfile, $f, $d) = @_;
    my($b) = basename($f);
    my($cat, $base) = &cat_and_base($f);
    my($tm) = &date_to_tm($d);
    our($max_sample, $opt_r, $opt_v, $opt_D, $retention_time, %base, $fd);
    our(%sample_time);

    if ($cat ne "cat") {
	if ($opt_v) {
	    printf(STDERR "No cat for %s, skipping\n", $f);
	}
	return undef;
    }

    &restore_vars($b);

    my $name = &file_to_name($b, &today);
    if (defined($opt_D) && $opt_D eq $name) {
	printf(STDERR "Restored data for %s:\n", $name);
	printf(STDERR "Sample_time{-1} = %s\n", $sample_time{-1});
	
    }

    open(IN, $f) || return undef;
    &position_file(\*IN, $b);
    &read_log(\*IN, $tm);
    &save_position(\*IN, $b);
    close(IN);

    my $name = &file_to_name($b, &today);
    if (defined($opt_D) && $opt_D eq $name) {
	printf(STDERR "Read data for %s, %d samples\n", $name, $max_sample + 1);
    }

    if ($max_sample != -1) {
	# for type of octet counter detection in process_data()
	foreach my $v (keys %base) {
	    $fd->{$b}->{"base"}->{$v} = $base{$v};
	}

	&process_data($b, 0, $max_sample, $tm);
	&trim_data($b, &timelocal(localtime) - $retention_time);
	&save_vars($b);
    } else {
	if (defined($opt_v)) {
	    printf(STDERR "No new data from %s, reporting old values\n", $b);
	}
    }
    if (defined($opt_r)) {
	&report_tail_stats($rfile, $b, $opt_r);
    }
}

# Read in data for one logical port and portion it up for the
# processing routines elsewhere in this file.

sub do_one_file {
    my($dsp, $name) = @_;
    my($i);
    our($max_sample, %sample_time, $fd, %base, $date, $opt_I);
    our(%lasttime, %firsttime, %dstcomp, $retention_time, $opt_v);

    # For undef'ing after processing one file
    our(%count, $ifspeed, $iftype, $ifdescr);

    my($base_tm, $nd) = &decode_datespec($dsp);

    if (defined($opt_I)) {
	unlink(sprintf("%s.rrd", $name));
    }

    foreach my $day (0 .. $nd-1) {
	my($tm) = $base_tm + 3600 * 24 * $day;
	# 2h+ to compensate for effects of DST, only use to compute day...
	my($day_tm) = $tm + 7200;
	my($d) = &tm_to_date($day_tm);

	if ($opt_v) {
	    printf(STDERR "Processing %s / %s\n", $name, $d);
	}

	my($b) = &name_to_file($name, $d);
	if (! defined($b)) {
	    printf(STDERR "Could not find file name for %s / %s\n",
		   $name, $d);
	    next;
	}

	my($cat, $f) = &find_cat_and_file($b, $d);
	if (! defined($f)) {
	    printf(STDERR "Could not find data file for %s / %s\n",
		   $b, $d);
	    next;
	}

	&restore_vars($b);

	if (!open(DAYLOG, "$cat $f |")) {
	    printf(STDERR "Could not open \"|%s %s\": %s\n", $cat, $f, $!);
	    next;
	}
	&read_log(\*DAYLOG, $tm);
	close(DAYLOG);
    
	if ($max_sample == 0) {
	    next;
	}
	# for type of octet counter detection in process_data()
	foreach my $v (keys %base) {
	    $fd->{$b}->{"base"}->{$v} = $base{$v};
	}

	my($t0) = str2time($date);

	# set up to process 6 hours at a time, but at least 4 samples
	# on each go-around
	my($samples_per_go) = &max(4, int($max_sample / 4));

	for($i = 0; $i <= $max_sample; $i += $samples_per_go) {
	    my $top = &min($i + $samples_per_go - 1, $max_sample);

	    &process_data($b, $i, $top, $tm);
	    &trim_data($b, (&convert_time($sample_time{$top}, $t0) -
			    $retention_time));
	}
	&save_vars($b);
    }

    undef %count;
    undef %base;
    undef %sample_time;
    undef %lasttime;
    undef %firsttime;
    undef %dstcomp;
    undef $date;
    undef $ifspeed;
    undef $iftype;
    undef $ifdescr;
    undef $max_sample;
}

sub child_process_files {
    my($pid, $d, $dsp, @l) = @_;
    our($opt_v);

    my $nf = 0;
    foreach my $f (@l) {
	my($name) = &file_to_name($f, $d);
	if (!defined($name)) { next; }
	if (defined($opt_v)) {
	    printf(STDERR
		   "Pid %s doing %s / %s / %s\n",
		   $pid, $d, $name, $f);
	}
	&do_one_file($dsp, $name);
	$nf++;
    }
    if (defined($opt_v)) {
	printf(STDERR
	       "Pid %d exiting after processing %d files\n",
	       $pid, $nf);
    }
    exit(0);
}


sub do_all_files {
    my($dsp) = @_;
    my($i);
    our($max_sample, %sample_time, $fd, %base, $date, $opt_v, $opt_j);

    my($base_tm, $nd) = &decode_datespec($dsp);
    if (!defined($base_tm)) {
	die "Could not decode datespec: $dsp";
    }

    foreach my $day (0 .. $nd-1) {
	# 7200 = 2h to compensate for DST shifts
	my($tm) = $base_tm + 7200 + $day * 3600 * 24;
	my($d) = &tm_to_date($tm);
	my($dsp) = &date_to_datespec($d, "day");
	my($dir) = &find_data_dir($d);
	my(@files) = &directory_files($dir);
	my(%file, @bns);
	
	# Weed out duplicate logical port names
	# before potentially processing them in parallel
	foreach my $f (@files) {
	    $f =~ s/.gz$//;
	    my $b = basename($f);
	    my $n = &file_to_name($b, $d);
	    if (! defined($n)) { next; }
	    if (! defined($file{$n})) {
		$file{$n} = $b;
		push(@bns, $b);
	    } else {
		printf(STDERR "Skipping dup port name: %s / %s," .
		       " already seen at %s\n",
		       $n, $b, $file{$n});
	    }
	}


	# Parallel processing requested?
	# If you have more I/O capacity than single-core CPU speed,
	# and have multiple cores, you may gain by using this
	if (defined($opt_j) && $opt_j > 1) {
	    my($inc, $p, $pid);

	    $inc = int(($#bns + 1) / ($opt_j));
	    if ($inc == 0) { $inc = 1; }
	    $p = 0;
	    while($p <= $#bns) {
		my($m);

		$m = &min($p + $inc - 1, $#bns);

		if (($pid = fork()) == 0) {
		    &child_process_files($$, $d, $dsp, @bns[$p .. $m]);
		}
		if (defined($opt_v)) {
		    printf(STDERR
			   "Forked pid %d for processing %d files" .
			   ", from %s to %s\n",
			   $pid, $m - $p + 1, $p, $m);
		}
		$p += $inc;
	    }
	    # Wait for all the children to finish
	    while(($pid = wait()) != -1) {
		if (defined($opt_v)) {
		    printf(STDERR "Reaped pid %d\n", $pid);
		}
	    }
	} else {
	    foreach my $f (@bns) {
		my($name) = &file_to_name($f, $d);
		if (!defined($name)) { next; }
		if (defined($opt_v)) {
		    printf(STDERR "Doing %s / %s / %s\n", $d, $name, $f);
		}
		&do_one_file($dsp, $name);
	    }
	}
    }
}

sub just_past_midnight {
    my($d1) = &tm_to_date($^T);
    my($d2) = &tm_to_date($^T - 20*60);

    return ($d1 ne $d2);
}

sub do_all_files_today {
    my($d);
    our($opt_V);

    if (&just_past_midnight()) {
	$d = &yesterday();
    } else {
	$d = &today();
    }
    my($dir) = &find_data_dir($d);
    my(@files) = &directory_files($dir);
    our($stat_report);
    our($opt_m, $opt_M, $opt_r);

#    select(STDOUT); $| = 1;	# unbuffer
    $stat_report = "";
    if (defined($opt_r)) {
	unlink($opt_r . ".new"); # ignore error
	open(REP, ">" . $opt_r . ".new") ||
	    die "Could not open $opt_r.new for write: $!";
    }

    foreach my $f (@files) {
	&tail_process_file(\*REP, $dir . "/" . $f, $d);
	if (defined($opt_V)) {
	    printf(".");
	}
    }
    if (defined($opt_r)) {
	close(REP);
	rename($opt_r . ".new", $opt_r); # atomic op on local file system
    }
    if ($stat_report != "" && defined($opt_m) && defined($opt_M)) {
	&mail_report($opt_M, $opt_m, $stat_report);
    }
    if (defined($opt_V)) {
	printf("\n");
    }
}

sub usage {

    printf(STDERR "usage: tail-stats [-n name] [-d datespec] [-u up-limit]\n");
    printf(STDERR "    [-l low-limit] [-p percent] [-r outfile] [-i]\n");
    printf(STDERR "    [-m mailto -M mailfrom] [-R rrddir] [-v] [-V]\n");
    printf(STDERR "\n");
    printf(STDERR "Option descriptions:\n");
    printf(STDERR "-n name      logical name of port to be analyzed\n");
    printf(STDERR "             (default is all logical ports, but see -i)\n");
    printf(STDERR "-d datespec  date(s) which should be analyzed\n");
    printf(STDERR "             (default is current day, ");
    printf(STDERR "start from end of last run)\n");
    printf(STDERR "-u up-limit  factor on an up-transition for flagging\n");
    printf(STDERR "-l low-limit factor to go below when de-flagging\n");
    printf(STDERR "-p percent   how many percent should data from new");
    printf(STDERR " interval count\n");
    printf(STDERR "-t time	retain data for this many seconds" .
	   " (default 3600)\n");
    printf(STDERR "-R rrddir    update RRD databases in the given directory\n");
    printf(STDERR "-r outfile   produce report about current load\n");
    printf(STDERR "             only applicable when doing current day\n");
    printf(STDERR "-I           initialize RRD databases (delete old)\n");
    printf(STDERR "-i           ignore unnamed logical ports when");
    printf(STDERR " making report\n");
    printf(STDERR "-m mailto    mail statistical deviations report to addr\n");
    printf(STDERR "-M mailfrom  set from address for stat dev. reports\n");
    printf(STDERR "-N           no deviation processing\n");
    printf(STDERR "-j <jobs>    Parallelize historical re-processing (-d)\n");
    printf(STDERR "-v           output some verbose debugging info\n");
    printf(STDERR "-V           output extra-verbose debugging info\n");
    printf(STDERR "-D portname  Do debugging for only the given port name\n");

    exit 1;
}

#
# Main
#

our($opt_h, $opt_m, $opt_M, $opt_t, $opt_u, $opt_l, $opt_p, $opt_r,
    $opt_R, $opt_n, $opt_d, $opt_j, $opt_D);

&getopts("D:d:hij:Il:M:m:Nn:p:R:r:t:u:vV");

if (defined($opt_h)) {
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

if (defined($opt_t) && $opt_t =~ /\d+/) {
    $retention_time = $opt_t;
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

if (defined($opt_R)) {
    if (! -d $opt_R) {
	printf(STDERR "Must specify an existing dir with -R\n");
	&usage();
    }
    chdir($opt_R) || die "Could not chdir to $opt_R: $!";
}

# Make STDERR flush output immediately
my $oldfh = select(STDERR); $| = 1; select($oldfh);

if (defined($opt_d) && defined($opt_n)) {
    if (defined($opt_r)) {
	printf(STDERR "-r ignored while procesing old stats\n");
	undef $opt_r;
    }
    my @names;
    @names = split(/,/, $opt_n);
    foreach my $n (@names) {
	&do_one_file($opt_d, $n);
    }
} elsif (defined($opt_n)) {
    my @names;
    @names = split(/,/, $opt_n);
    my $d;
    if (&just_past_midnight()) {
	$d = &yesterday_spec();
    } else {
	$d = &today_spec();
    }
    foreach my $n (@names) {
	&do_one_file($d, $n);
    }
} elsif (defined($opt_n)) {
    my @names;
    @names = split(/,/, $opt_n);
    my $d;
    if (&just_past_midnight()) {
	$d = &yesterday_spec();
    } else {
	$d = &today_spec();
    }
    foreach my $n (@names) {
	&do_one_file($d, $n);
    }
} else {
    if (defined($opt_d)) {
	&do_all_files($opt_d);
    } else {
	&do_all_files_today();
    }
}
