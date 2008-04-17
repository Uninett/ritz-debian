#!%PERL%
#
# $Id$
#

# Copyright (c) 1999
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

# Extracts one or more statistical values for kbit/s data rate for a
# given day for a given port.
#
# Options:
#   -d <datespec>
#       yyyy-mm--dd for a day
#       yyyy-mm-dd for a day
#       (default is yesterday)
#   -n <name> 	name of logical port, mandatory
#   -a		produce average value, preceded by "avg: "
#   -i <inc>	produce every <inc> percentile, preceded by "%d perc: "
#   -p <perc>	produce the <perc>th percentile, preceded by "%d perc: "
#   -w <start-hh>-<end-hh> restrict data for calculation to that
# 			falling in the given hour interval
#   -s		swap direction (default is "out")
#

push(@INC, "%LIBDIR%");

require 'getopts.pl';

require 'date.pl';
require 'db-lookup.pl';
require 'search.pl';
require 'read-raw-log.pl';
require 'scaling.pl';
require 'plot.pl';
require 'utils.pl';


sub read_data {
    my($name, $dsp) = @_;
    my($tm, $nd, $date, $base, $f, $cat);

    ($tm, $nd) = &decode_datespec($dsp);
    $date = &tm_to_date($tm);
    if (! defined($base = &name_to_file($name, $date))) {
	die "Could not find base file name for $name / $date\n";
    }
    ($cat, $f) = &find_cat_and_file($base, $date);
    if (! defined($f)) {
	die "Could not find data file for $base / $date\n";
    }
    open(DAYLOG, "$cat $f |") ||
	die "Could not open \"$cat $f\": $!\n";
    &read_log(DAYLOG, $tm);
    close(DAYLOG);
}

# Leave data values in global @data

sub collect_data {
    my($i, $h, $val, $v, %then, $now, %add);
    my($vl);

    if (defined($opt_s)) {
	$v = "ifInOctets";
    } else {
	$v = "ifOutOctets";
    }
    
    foreach $i (0 .. $max_sample) {
	if ($i == 0) {
	    $then{$v} = $sample_time{$v,0};
	    next;
	}

	$now = $sample_time{$v,$i};
	$time_delta = 3600.0 * ($now - $then{$v});
	if ($time_delta < 0) {	# Ignore samples before midnight the 
	    $add{$v} = 0;	# "previous" day (not sure this comes out
	    $then{$v} = $now;	# exactly right...
	} elsif ($time_delta <= 30) { # Skip samples w. too small interval
	    $add{$v} += $count{$v,$i}; # But add data
	} else {
	    $then{$v} = $now;
	    &maxit($val =
		   ($count{$v,$i} + $add{$v}) * 8 / $time_delta / 1000);
	    $add{$v} = 0;
	    if ($now >= $start_hh && $now <= $end_hh) {
		push(@data, $val);
	    }
	}
    }
}

sub process_data {
    
    @sorted_data = sort {$a <=> $b} @data;
}

sub print_data {
    my($sum, $i, $p);

    if (defined($opt_a)) {	# print average
	foreach $v (@data) {
	    $sum += $v;
	}
	printf("avg: %f\n", $sum / $#data);
    }
    if (defined($opt_p)) {	# print given percentile
	$i = int($#sorted_data * $opt_p / 100);
	printf("%d perc: %s\n", $opt_p, $sorted_data[$i]);
    }
    if (defined($opt_i)) {	# print each <inc> percentile
	for ($p = 0; $p <= 100; $p += $opt_i) {
	    $i = int($#sorted_data * $p / 100);
	    printf("%d perc: %s\n", $p, $sorted_data[$i]);
	}
    }
}

#
# Main
#

&Getopts("ad:i:n:p:sw:");

$name = $opt_n;
$datespec = $opt_d;

if (!defined($name)) { die "You have to specify the port name\n"; }
if (!defined($datespec)) { $datespec = &yesterday_spec(); }

($base_tm, $no_days) = &decode_datespec($datespec);
if ($no_days != 1) { die "Can only extract values for a single day\n"; }

if (defined($opt_w)) {
    ($start_hh, $end_hh) = split(/-/,$opt_w);
} else {
    $start_hh = 0.0;
    $end_hh = 24.0;
}

&read_data($name, $datespec);
&collect_data();
&process_data();
&print_data();
