#!/usr/bin/perl
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

require "getopts.pl";

# push(@INC, "%LIBDIR%");
push(@INC, "/archive/traffic/lib");
push(@INC, "/archive/traffic/conf");

require "date.pl";
require "search.pl";
require "db-lookup.pl";
require "utils.pl";
require "read-raw-log.pl";

require "config.pl";

use Data::Dumper;
use File::Basename;
use Fcntl qw(:seek);

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

sub convert_times {
    my($times) = @_;
    my($s, $i);
    our(%sample_time, %base);
    our(%sample_secs);

    # Handle the stupidity that the time scale is in hours
    # for the "current day", and handle rollover at midnight
    if(defined($sample_time{-1})) {
	$s = -1;
    } else {
	$s = 0;
    }
    for($i = $s; $sample_time{$i} > $sample_time{$max_sample}; $i++) {
	$sample_time{$i} -= 24;
	foreach my $k (keys %base) {
	    $sample_time{$k,$i} -= 24;
	}
    }
    my $start_secs = &date_to_tm(&today());
    for($i = $s; $i <= $max_sample; $i++) {
	my $secs = $start_secs + 3600.0 * $sample_time{$i};
	if ($i != $s) {
	    push(@$times, $secs);
	}
	$sample_secs{$i} = $secs;
    }
}

sub compute_basic_values {
    my($b, $d) = @_;
    my($i);
    our($max_sample, %count);
    our(%sample_secs);

    for ($i = 0; $i <= $max_sample; $i++) {
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

sub process_values {
    my($b, $d) = @_;
    my($i);
    our($fd);

    # We could do statistical processing on the values here,
    # or we could just write another script which uses the
    # state from the saved files.

    if (0) {
	foreach my $k (keys %$d) {
	    my $a = $d->{$k}->{"values"};
	    printf("%s #values: %d\n", $k, $#$a);
	    }
	printf("max_sample: $max_sample\n");
	printf("done\n");
    }
}

sub save_and_trim {
    my($b, $d) = @_;
    our($fd);
    my($sp) = $fd->{$b}->{"save_values"};
    my($stp) = $d->{"sample_times"}->{"values"};
    my($save_ap, $ap);

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

    # Trim out samples older than $retention_time
    my $now = &timelocal(localtime);
    $stp = $sp->{"sample_times"};
    while (defined($$stp[0]) && $$stp[0] < $now - $retention_time) {
	foreach my $k (keys %$d) {
	    my($ap) = $sp->{$k};
	    shift(@$ap);
	}
    }
}

sub process_data {
    my($b) = @_;
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

    &convert_times(\@times);

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

    &compute_basic_values($b, $desc);

    # bytes per packet derived from values computed above
    for ($i = 0; $i <= $max_sample; $i++) {
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
    &save_and_trim($b, $desc);
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

sub report {
    my($b) = @_;
    our($fd);
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
	$name = $b;
    }
    # Output: name   last-kbps-in last-kbps-out avg-kbps-in avg-kbps-out
    printf("%-30s %8d %8d %8d %8d %8d\n",
	   $name,
	   $ia->[$#$ia],
	   $oa->[$#$oa],
	   $ikbps, $okbps,
	   $fd->{$b}->{"ifspeed"} / 1000,
	   );
#    printf("\n");
}

sub tail_process_file {
    my($f) = @_;
    my($b) = basename($f);
    my($cat, $base) = &cat_and_base($f, &today());

    if ($cat ne "cat") { return undef; }

    &restore_vars($b);

    open(IN, $f) || return undef;
    &position_file(\*IN, $b);
    &read_log(\*IN, 1);
    &save_position(\*IN, $b);
    close(IN);

    &process_data($b);
    &save_vars($b);
    &report($b);
}

sub do_all_files {
    my($dir) = &find_data_dir(&today());
    my(@files) = &directory_files($dir);

#    select(STDOUT); $| = 1;	# unbuffer
    foreach $f (@files) {
	&tail_process_file($dir . "/" . $f);
#	printf(".");
    }
#    printf("\n");
}

#
# Main
#

&do_all_files();
