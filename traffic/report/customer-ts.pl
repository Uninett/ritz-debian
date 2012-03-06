#! %PERL%

# $Id$

# Copyright (c) 2008
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

#
# Script doing "tail-stats" but per-customer instead of per-connection,
# optionally feeding the result into RRD databases.
#
# There's probably no need for "statistics deviation" processing here,
# as that's already being done by "tail-stats".
# 

push(@INC, "%LIBDIR%");
push(@INC, "%CONFDIR%");

require 'getopts.pl';

require "date.pl";
require "search.pl";
require "db-lookup.pl";
require "utils.pl";
require "read-5m-sum.pl";

require "zino-config.pl";

use lib qw(%LIBDIR%);

use Zino::conn qw(read_desc select_types %fullname %ports);
use Data::Dumper;
use File::Basename;
use Fcntl qw(:seek);
use Date::Parse;
use Date::Format;

use strict;
no strict "vars";

sub save_file {
    my($c) = @_;
    our($DATATREE);

    return $DATATREE . "/c-tail/" . $c . ".pl";
}

%save_hashes = ("position" => \%position,
		"dstcomp" => \%dstcomp,
		"leftover" => \%leftover,
		"save_base" => \%save_base,
		"save_lasttime" => \%save_lasttime,
		"save_varnames" => \%save_varnames,
		"lastfilebase" => \%lastfilebase,
		"ifspeed" => \%ifspeed,
    );
%save_vars = ("date" => \$date);


sub save_vars {
    my($c) = @_;
    my($p);
    our($root);
    our(%save_hashes, @save_vars);

    $p = $root->{$c};

    foreach my $h (keys %save_hashes) {
	my($hp) = $save_hashes{$h};
	foreach my $v (keys %{ $hp }) {
	    $p->{$h}->{$v} = $hp->{$v};
	}
    }
    foreach my $v (keys %save_vars) {
	my($vp) = $save_vars{$v};
	$p->{$v} = ${ $vp };
    }

    my $f = &save_file($c);
    open(OUT, ">" . $f . ".new") ||
	die "Could not open $f.new for write: $!";
    print OUT Data::Dumper->Dump([$p], ["p"]);
    close(OUT);
    rename($f . ".new", $f);

    foreach my $h (keys %save_hashes) {
	my($hp) = $save_hashes{$h};
	undef %{ $hp };
    }
}

sub restore_vars {
    my($c) = @_;
    our($root);
    our(%save_hashes, @save_vars);
    my($p) = $root->{$c};

    if (!defined($p->{"date"})) {
	my $f = &save_file($c);
	if (open(IN, $f)) {
	    my @lines = <IN>;
	    close(IN);
	    my $var_settings = join("", @lines);
	    eval $var_settings;
	    $root->{$c} = $p;
	}
	foreach my $h (keys %save_hashes) {
	    my($hp) = $save_hashes{$h};
	    foreach my $v (keys %{ $p->{$h} }) {
		$hp->{$v} = $p->{$h}->{$v};
	    }
	}
	foreach my $v (keys %save_vars) {
	    my($vp) = $save_vars{$v};
	    ${ $vp } = $p->{$v};
	}
    }
}

sub convert_time {
    my($t, $ss) = @_;

    if (!defined($ss)) {
	$ss = &date_to_tm(&today());
    }
    return $ss + 3600.0 * $t;
}

sub convert_times {
    my($times, $start, $end, $tm0) = @_;
    my($s, $i);
    our(%sample_time);
    our(%sample_secs, $max_sample);
    my($start_secs);

    if(defined($sample_time{$start-1})) {
	$s = $start-1;
    } else {
	$s = $start;
    }

    if(defined($tm0)) {
	$start_secs = $tm0;
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

sub secs_to_hms {
    my($secs) = @_;

    return sprintf("%02d:%02d:%02d",
		   ($secs % 86400) / 3600,
		   ($secs - (int($secs / 3600) * 3600)) / 60,
		   $secs % 60);
}

sub compute_basic_values {
    my($d, $start, $end, $tm0) = @_;
    my($i);
    our(%count, %sample_secs);
    our($opt_V);
    our($ifspeed);

    for ($i = $start; $i <= $end; $i++) {
	if (!defined($sample_secs{$i-1})) {
	    next;
	}
	$delta_t = $sample_secs{$i} - $sample_secs{$i-1};

	if ($delta_t == 0) { next; }

	if ($opt_V) {
	    printf(STDERR "deltaT: %s", $delta_t);
	    printf(STDERR " %s ", &secs_to_hms($sample_secs{$i} - $tm0));
	}

	foreach my $k (sort keys %$d) {
	    my($ap) = $d->{$k}->{"values"};
	    my(@vars) = @{ $d->{$k}->{"vars"} };
	    my($mult) = $d->{$k}->{"mult"};

	    my($v) = 0;
	    my($ov) = 0;
	    foreach my $var (@vars) {
		$v += $count{$var,$i};
		if ($var =~ /Octets/o) {
		    $ov = 1;
		}
	    }
	    my($val) = $v * $mult / $delta_t;

	    # If processing an octet counter, check that we're
	    # within ifSpeed's range, balk otherwise and set sample to zero.
	    if ($ov && $ifspeed != 0) {
		my($br) = $val * 1000.0;
		if ($br > $ifspeed) {
		    printf(STDERR
			   "ERROR: Bitrate above ifSpeed for %s: %s vs %s" .
			   ", sample ignored\n",
			   $b, $br, $ifspeed);
		    $val = 0;
		}
	    }

	    push(@$ap, $val);
	    if ($opt_V) {
		printf(STDERR " %s: %14f", $k, $val);
	    }
	}
	if ($opt_V) {
	    printf(STDERR "\n");
	}
    }
}

sub save_values {
    my($d, $hp, $ns) = @_;

    foreach my $k (keys %{ $d }) {
	$hp->{$k} = {};
	$hp->{$k}->{"values"} = ();
	foreach my $n (0 .. $ns-1) {
	    unshift(@{ $hp->{$k}->{"values"} },
		    pop(@{ $d->{$k}->{"values"} }));
	}
    }
}

sub merge_values {
    my($d, $sp, $tm0) = @_;
    my(@saved_times);
    my($i) = 0;
    my($tr, $shift);
    our($opt_V);

    @saved_times = @{ $sp->{"sample_times"}->{"values"} };
    $tr = $d->{"sample_times"}->{"values"};
    $shift = 0;

    for (my $n = $#saved_times; $n >= 0; $n--) {
	$ts = $saved_times[$n];
	if ($ts < ${ $tr }[$0]) {
	    $shift++;
	    $i++;
	    if ($opt_V) {
		printf(STDERR "Shifting in sample at %s\n",
		       &secs_to_hms($ts - $tm0));
	    }
	    foreach my $k (keys %{ $sp }) {
		unshift(@{ $d->{$k}->{"values"}},
			${ $sp->{$k}->{"values"}}[$n]);
		if ($opt_V) {
		    printf(STDERR "%s: %s ", $k,
			   ${ $sp->{$k}->{"values"}}[$n]);
		}
	    }
	    if ($opt_V) {
		printf(STDERR "\n");
	    }
	}
    }
    foreach my $n (1 .. $shift) {
	foreach my $k (keys %{ $sp }) {
	    shift(@{ $sp->{$k}->{"values"} });
	}
    }

    @saved_times = @{ $sp->{"sample_times"}->{"values"} };

    foreach my $ts (@saved_times) {
	while($ts != ${ $tr }[$i] && defined(${ $tr }[$i])) {
	    $i++;
	}
	if ($ts == ${ $tr }[$i]) {
	    if ($opt_V) {
		printf(STDERR "Merging sample at    %s\n",
		       &secs_to_hms($ts - $tm0));
	    }
	    foreach my $k (keys %{ $sp }) {
		if ($k eq "sample_times") {
		    shift(@{ $sp->{$k}->{"values"}});
		    next;
		}
		my($add);
		$add = shift(@{ $sp->{$k}->{"values"}});
		${ $d->{$k}->{"values"} }[$i] += $add;
		if ($opt_V) {
		    printf(STDERR "%s: %s ", $k, $add);
		}
	    }
	    if ($opt_V) {
		printf(STDERR "\n");
	    }
	}
	$i++;
    }
}

sub process_data {
    my($c, $start, $end, $tm0, $save_count) = @_;
    our($root, $opt_R, $opt_N, $opt_V);
    my($p) = $root->{$c};
    my($iov, $oov);
    my(@in_kbps, @out_kbps, @in_pps, @out_pps, @times);
    our(%sample_secs);
    
    # Prefer 64-bit counters
    if (defined($p->{"base"}->{"ifHCInOctets"})) {
	$iov = "ifHCInOctets";
	$oov = "ifHCOutOctets";
    } else {
	$iov = "ifInOctets";
	$oov = "ifOutOctets";
    }
    
    if (defined($opt_V)) {
	our(%sample_time);

	printf(STDERR "Times before convert_times:\n");
	foreach my $i ($start .. $end) {
	    printf(STDERR "time: %f\n", $sample_time{$i});
	}
    }

    &convert_times(\@times, $start, $end, $tm0);

    if (defined($opt_V)) {
	printf(STDERR "Times after convert_times:\n");
	foreach my $t (@times) {
	    printf(STDERR "time: %s -- %s\n", $t,
		   &secs_to_hms($t - $tm0));
	}
    }


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
    
    &compute_basic_values($desc, $start, $end, $tm0);
    $desc->{"sample_times"}->{"values"} = \@times;

    if (defined($p->{"saved_values"})) {
	&merge_values($desc, $p->{"saved_values"}, $tm0);
    }

    if (defined($save_count) && !defined($opt_N)) {
	$p->{"saved_values"} = {};
	&save_values($desc, $p->{"saved_values"}, $save_count);
    }

    # This used only in-kbps, out-kbps and sample times
    # so do this now before we destroy the values in $desc
    if (defined($opt_R)) {
	&update_rrd($c, $desc, $tm0);
    }
    undef %sample_secs;
}

sub create_rrd {
    my($name) = @_;
    my($cmd);
    our($opt_V);

    # 4 years in the past as starting point
    my($s) = $^T - (4 * 365) * 24 * 3600;

    $cmd = "rrdtool create %s.rrd ";
    $cmd .= "--start %d ";
    $cmd .= "-s 300 ";
    $cmd .= "DS:In:GAUGE:600:0:U ";
    $cmd .= "DS:Out:GAUGE:600:0:U ";
    # 72 hours of 5-minute intervals
    $cmd .= "RRA:AVERAGE:0.5:1:864 ";
    # 21 days of 30-minute intervals
    $cmd .= "RRA:AVERAGE:0.5:6:1008 ";
    # 62 days of 2-hour intervals
    $cmd .= "RRA:AVERAGE:0.5:24:744 ";
    # 1095 days (3 years) of 24-hour intervals
    $cmd .= "RRA:AVERAGE:0.5:288:730 ";

    # And similar for the max values:
    $cmd .= "RRA:MAX:0.5:1:864 ";
    $cmd .= "RRA:MAX:0.5:6:1008 ";
    $cmd .= "RRA:MAX:0.5:24:744 ";
    $cmd .= "RRA:MAX:0.5:288:730 ";

    if ($opt_V) {
	printf(STDERR "$cmd\n", $name, $s);
    }
    if (system(sprintf($cmd, $name, $s)) != 0) {
	printf(STDERR "rrdtool create %s.rrd failed: %s", $name, $?);
	return undef;
    }
    return 1;
}

sub time_str {
    my($t) = @_;
    my($s, $m, $h, $md, $mon, $y, $wd, $yd, $dst) = localtime($t);

    return sprintf("%d-%02d-%02d %02d:%02d:%02d",
		   $y + 1900, $mon+1, $md,
		   $h, $m, $s);
}

sub update_rrd {
    my($c, $d, $tm0) = @_;
    my($i);
    our($opt_N, $opt_V);
    my($name);

    if (-f $c . ".lock") { return; }
    if (! -f $c . ".rrd" && !defined($opt_N)) {
	&create_rrd($c) || return;
    }
    my($eoa) = $#{ $d->{"sample_times"}->{"values"} };
    my($tap) = $d->{"sample_times"}->{"values"};
    my($iap) = $d->{"ikbps"}->{"values"};
    my($oap) = $d->{"okbps"}->{"values"};
    # report to RRD in bit/s
    for ($i = 0; $i <= $eoa; $i++) {
	if (!defined($opt_N)) {
	    printf(RRD "update %s.rrd %d:%f:%f\n",
		   $c, $tap->[$i],
		   $iap->[$i] * 1000.0,
		   $oap->[$i] * 1000.0);
	}
	if ($opt_V) {
	    printf(STDERR "RRD-update %s %f %f %s.rrd\n",
		   &time_str($tap->[$i]),
		   $iap->[$i] * 1000.0,
		   $oap->[$i] * 1000.0,
		   $c);
	}
    }
}

sub just_past_midnight {
    my($td) = @_;

    my($d1) = &tm_to_date($^T);
    # some extra slop, to pick up data at day roll-over
    my($d2) = &tm_to_date($^T - $td - 360);

    return ($d1 ne $d2);
}

sub do_all_lines {
    my($dsp, $c, @lines) = @_;
    our($tail_delay);
    our($root, %base);
    our($opt_v, $opt_N);
    our($min_sample, $max_sample);
    
    my($td) = $tail_delay;
    
    # In "tail" mode, mop up the rest of yesterday's data
    # if we're started just past midnight
    if ($dsp eq &today_spec()) {
	if (&just_past_midnight($td)) {
	    $dsp = &yesterday_spec();
	}
    } else {
	undef $td;
    }

    my($base_tm, $nd) = &decode_datespec($dsp);
    if (!defined($root->{$c})) {
	$root->{$c} = {};
    }

    if ($opt_v) {
	printf(STDERR "Doing %s / %s\n", $dsp, $c);
    }

    &restore_vars($c);

    my($ls) = join("+", @lines);
    foreach my $day (0 .. $nd-1) {
	my($tm) = $base_tm + 3600 * 24 * ($day);
	my($d) = &tm_to_date($tm + 12*3600);
	$tm = &date_to_tm($d);

	my $err = &read_5m_sum($ls, $d, $td);
	if ($opt_v && $err ne "") {
	    printf(STDERR "read_5m_sum returned:\n%s", $err);
	}

	if ($max_sample == 0) {
	    if ($opt_v) {
		printf(STDERR "max_sample == 0, no data for %s / %s?\n",
		       $d, $c);
	    }
	    next;
	}
	if ($opt_v) {
	    printf(STDERR "Processing %s / %s\n", $d, $c);
	}

	# for type of octet counter detection in process_data()
	foreach my $v (keys %base) {
	    $root->{$c}->{"base"}->{$v} = $base{$v};
	}
	
	# Stitch together samples at the end of collected data.
	# When processing many files, the edges become "ragged"...
	&process_data($c, $min_sample, $max_sample, $tm, 2);
    }

    if (!defined($opt_N)) {
	&save_vars($c);
    }
}

sub do_one_customer {
    my($dsp, $c) = @_;
    our(%ports);

    &do_all_lines($dsp, $c, @{ $ports{$c} });
}

sub do_all_customers {
    my($dsp) = @_;
    our(%fullname);

    foreach $c (keys %fullname) {
	&do_one_customer($dsp, $c);
    }
}

sub do_category {
    my($dsp, $c_name, $expr) = @_;
    our(%fullname, %ports);
    my(@c_list, @p_list);

    @p_list = ();
    @c_list = &select_types($expr, keys %fullname);
    foreach my $cust (@c_list) {
	push(@p_list, @{ $ports{$cust} });
    }
    &do_all_lines($dsp, $c_name, @p_list);
}

sub usage {

    printf(STDERR "usage: customer-ts -c config [-d datespec] [-n name]\n");
    printf(STDERR "       [-R rrd-dir] [-v] [-V]\n");
    printf(STDERR "Options:\n");
    printf(STDERR "-c config     config file for customers / connections\n");
    printf(STDERR "-d datespec   datespec for period to be analyzed\n");
    printf(STDERR "-n name       logical name of customer to be analyzed\n");
    printf(STDERR "-N            don't update anything -- dry-run\n");
    printf(STDERR "-R rrddir     update RRD databases in this directory\n");
    printf(STDERR "-v            output debugging output\n");
    printf(STDERR "-V            output extra-verbose debugging output\n");
    printf(STDERR "-e expr       a type-expression to be used with -C\n");
    printf(STDERR "-C category   name the category implied by the -e option\n");
    exit(1);
}

#
# Main
#

&Getopts("C:c:d:e:hNn:R:vV");

if ($opt_h) { &usage(); }

if (defined($opt_C) && !defined($opt_e)) {
    die "-C needs -e option as well";
}
if (defined($opt_e) && !defined($opt_C)) {
    die "-e needs -C option as well";
}

&read_desc($opt_c);

if (defined($opt_R)) {
    if (! -d $opt_R) {
	printf(STDERR "Must specify an existing dir with -R\n");
	&usage();
    }
    chdir($opt_R);
    open(RRD, "|rrdtool - 2>&1 | egrep -v '^OK'") ||
	die "Could not open rrdtool";
}

# Make STDERR flush output immediately
$oldfh = select(STDERR); $| = 1; select($oldfh);

if (defined($opt_d) && defined($opt_n)) {
    my(@n) = split(/,/, $opt_n);
    foreach my $cust (@n) {
	&do_one_customer($opt_d, $cust);
    }
} elsif (!defined($opt_d) && defined($opt_n)) {
    my(@n) = split(/,/, $opt_n);
    foreach my $cust (@n) {
	&do_one_customer(&today_spec(), $cust);
    }
} elsif (defined($opt_C) && defined($opt_e)) {
    if (defined($opt_d)) {
	&do_category($opt_d, $opt_C, $opt_e);
    } else {
	&do_category(&today_spec(), $opt_C, $opt_e);
    }
} else {
    if (defined($opt_d)) {
	&do_all_customers($opt_d);
    } else {
	&do_all_customers(&today_spec());
    }
}
if ($opt_R) {
    close(RRD);
}
