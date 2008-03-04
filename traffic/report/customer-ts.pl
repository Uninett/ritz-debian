#! /usr/bin/perl

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
require "read-5m-log.pl";
require "conn-common.pl";

require "config.pl";

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

@save_hashes = ("position",
		"dstcomp",
		"leftover",
		"save_base",
		"save_lasttime",
		"save_varnames",
    );
@save_vars = ("date");


sub save_vars {
    my($c) = @_;
    my($p);

    no strict 'refs';

    foreach my $h (@save_hashes) {
	our(%$h);
	foreach my $v (keys %$h) {
	    $p->{$h}->{$v} = $$h{$v};
	}
    }
    foreach my $v (@save_vars) {
	our($$v);
	$p->{$v} = $v;
    }

    my $f = &save_file($c);
    open(OUT, ">" . $f . ".new");
    print OUT Data::Dumper->Dump([$p], ["p"]);
    close(OUT);
    rename($f . ".new", $f);

    foreach my $h (@save_hashes) {
	our(%$h);
	undef %$h;
    }
}

sub restore_vars {
    my($c) = @_;
    our($root);

    if (!defined($root->{$c})) {
	my $f = $save_file($c);
	if (open(IN, $f)) {
	    my @lines = <IN>;
	    close(IN);
	    my $var_settings = join("", @lines);
	    eval $var_settings;
	    $root->{$c} = $p;
	}
    }

    foreach my $v (@save_vars) {
	our($$v);
	$v = $p->{$v};
    }

    if (defined($p)) {
	foreach my $h (@save_hashes) {
	    our(%$h);
	    foreach my $v (keys %{ $p->{$h} }) {
		$$h{$v} = $p->{$h}->{$v};
	    }
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

    # Handle that the time scale is in hours for the "current day",
    # and handle rollover at midnight, and that we may have some data
    # from "yesterday" at the start of the log file
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

sub compute_basic_values {
    my($d, $start, $end, $tap) = @_;
    my($i);
    our($max_sample, %count);

    for ($i = $start; $i <= $end; $i++) {
	if (!defined($tap->[$i-1])) {
	    next;
	}
	$delta_t = $tap->[$i] - $tap->[$i-1];

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

sub process_data {
    my($c, $start, $end, $tm0) = @_;
    our($root);
    my($p) = $root->{$c};
    my($iov, $oov);
    my(@in_kbps, @out_kbps, @in_pps, @out_pps, @times);
    
    # Prefer 64-bit counters
    if (defined($p->{"base"}->{"ifHCInOctets"})) {
	$iov = "ifHCInOctets";
	$oov = "ifHCOutOctets";
    } else {
	$iov = "ifInOctets";
	$oov = "ifOutOctets";
    }
    
    &convert_times(\@times, $start, $end, $tm0);

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
    
    &compute_basic_values($desc, $start, $end, \@times);

    $desc->{"sample_times"}->{"values"} = \@times;

    # This used only in-kbps, out-kbps and sample times
    # so do this now before we destroy the values in $desc
    if (defined($opt_R)) {
	&update_rrd($c, $desc, $tm0);
    }
}

sub create_rrd {
    my($name) = @_;
    my($cmd);
    our($opt_V);

    # 4 years in the past as starting point
    my($s) = time - (4 * 365) * 24 * 3600;

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

    if ($opt_V) {
	printf(STDERR "$cmd\n", $n, $s);
    }
    if (system(sprintf($cmd, $n, $s)) != 0) {
	printf(STDERR "rrdtool create %s.rrd failed: %s", $n, $?);
	return undef;
    }
    return 1;
}

sub time_str {
    my($t) = @_;
    my($s, $m, $h, $md, $mon, $y, $wd, $yd, $dst) = gmtime($t);

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
    if (! -f $c . ".rrd" && !defined($opt_N))) {
	&create_rrd($c) || return;
    }
    my($eoa) = $#{ $d->{"sample_times"}->{"values"} };
    my($tap) = $d->{"sample_times"}->{"values"};
    my($iap) = $d->{"ikbps"}->{"values"};
    my($oap) = $d->{"okbps"}->{"values"};
    for ($i = 0; $i <= $eoa; $i++) {
	if (!defined($opt_N)) {
	    printf(RRD "update $s.rrd %d:%f:$f\n",
		   $c, $tap->[$i],
		   $iap->[$i] / 1000.0,
		   $oap->[$i] / 1000.0);
	}
	if ($opt_V) {
	    printf(STDERR "RRD-update %s $f $f $s.rrd\n",
		   &time_str($tap->[$i]),
		   $iap->[$i] / 1000.0,
		   $oap->[$i] / 1000.0,
		   $c);
	}
    }
}

sub do_one_customer {
    my($dsp, $c) = @_;
    my($base_tm, $nd) = &decode_datespec($dsp);
    my($i);
    our($root, %base);

    if (!defined($root->{$c})) {
	$root->{$c} = {};
    }

    foreach my $day (0 .. $nd-1) {
	my($tm) = $base_tm + 3600 * 24 * $day;
	my($d) = &tm_to_date($tm);

	my(@lines) = @{ $ports{$c} };
	my($ls) = join("+", @lines);
	&read_5m_sum($ls, $d);

	if ($max_sample == 0) {
	    next;
	}
	# for type of octet counter detection in process_data()
	foreach my $v (keys %base) {
	    $root->{$c}->{"base"}->{$v} = $base{$v};
	}
	
	&process_data($c, 0, $max_sample, $tm);
    }
}

sub do_all_customers {
    my($dsp) = @_;
    our(%fullname);

    foreach $c (keys %fullname) {
	&do_one_customer($dsp, $c);
    }
}

sub do_all_customers_today {
}


sub usage {

    printf(STDERR "usage: customer-ts -c config [-d datespec] [-n name]\n");
    printf(STDERR "       [-R rrd-dir] [-v] [-V]\n");
    printf(STDERR "Options:\n");
    printf(STDERR "-c config      config file for customers / connections\n");
    printf(STDERR "-d datespec    datespec for period to be analyzed\n");
    printf(STDERR "-n name        logical name of customer to be analyzed\n");
    printf(STDERR "-N             don't update anything -- dry-run\n");
    printf(STDERR "-R rrddir      update RRD databases in this directory\n");
    printf(STDERR "-v             output debugging output\n");
    printf(STDERR "-V             output extra-verbose debugging output\n");
    exit(1);
}

#
# Main
#

&Getopts("c:d:Nn:R:vV");

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
    &do_one_customer($opt_d, $opt_n);
} else {
    if (defined($opt_d)) {
	&do_all_customers($opt_d);
    } else {
	&tail_all_customers();
    }
}
if ($opt_R) {
    close(RRD);
}
