#!%PERL%
#
# $Id$
#

# Copyright (c) 2002
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
push(@INC, "%LIBDIR%");

require 'getopts.pl';

require 'date.pl';
require 'db-lookup.pl';
require 'search.pl';
require 'read-5m-sum.pl';
require 'utils.pl';

sub addup_values {
    my($vref, $iref, $oref) = @_;
    my($in, $out);
    my(%then);
    
    foreach $i (0 .. $max_sample) {
	if ($i == 0) {
	    foreach $v (@{$vref}) {
		$then{$v} = $sample_time{$v,0};
	    }
	    next;
	}
	if (!$started) {
	    if ($sample_time{$vars[0],$i} > 23) {
		next;
	    }
	}
	$started = 1;

	undef $in;
	undef $out;

	foreach $v (@{$vref}) {
	    $now = $sample_time{$v,$i};
	    $time_delta = 3600.0 * ($now - $then{$v});
	    if ($time_delta < 0) { # Ignore samples before midnight the 
		$add{$v} = 0;	# "previous" day (not sure this comes out
		$then{$v} = $now; # exactly right...
	    } elsif ($time_delta <= 30) { # Skip samples w. too small interval
		$add{$v} += $count{$v,$i}; # But add data
	    } else {
		$then{$v} = $now;
		# Specialized for kbit/s computation
		$val = ($count{$v,$i} + $add{$v})
		    * 8.0/1000 / $time_delta;
		$add{$v} = 0;
		if ($v =~ /In/) {
		    $in = $val;
		} else {
		    $out = $val;
		}
	    }
	}
	if (defined($in) && defined($out)) {
	    push(@{$iref}, $in);
	    push(@{$oref}, $out);
#	    printf("in %s out %s\n", $in, $out);
	}
    }
    undef %count;
    undef %max_rate;
    undef $max_sample;
    undef %sample_delta;
    undef %sample_time;
}


sub get_percentile {
    my($dsp, $name, $perc) = @_;
    my($base_tm, $no_days) = &decode_datespec($dsp);
    my(@in, @out, @vars);
    my($in, $out);
    my($iov, $oov);

    return undef unless $base_tm;

    foreach $d (0 .. $no_days - 1) {
	$tm = $base_tm + ($d) * (60*60*24);
	$date = &tm_to_date($tm);
	&read_5m_sum($name, $date);

	if (! defined $vars[0]) {
	    $iov = &octets_var("in");
	    $oov = &octets_var("out");

	    push(@vars, $iov, $oov);
	}

	&addup_values(\@vars, \@in, \@out);
    }

    my $in  = &percentile($perc, @in);
    my $out = &percentile($perc, @out);

    return ($in, $out, $no_days);
}

sub usage {
    die "$0: usage: $0 [-N report-name] -d datespec -n portname -p percentile";
}


#
# Main
#

&Getopts("d:MN:n:p:");

if (!defined($opt_d)) { &usage(); }
if (!defined($opt_n)) { &usage(); }
if (!defined($opt_p)) { &usage(); }

($in, $out, $nd) = &get_percentile($opt_d, $opt_n, $opt_p);

if (defined($opt_M)) {		# Output in Mbit/s instead of kbit/s
    $in /= 1000;
    $out /= 1000;
}

if (!defined($opt_N)) {
    printf("%-15s %s (%d day%s) %d perc in %7.2f  out %7.2f (%s)\n",
	   $opt_n, $opt_d, $nd, $nd>1 ? "s" : "" , $opt_p, $in, $out,
	   $opt_M ? "Mbit/s" : "kbit/s"
	   );
} else {
    printf("%-15s %s (%d day%s) %d perc in %7.2f  out %7.2f (%s)\n",
	   $opt_N, $opt_d, $nd, $nd>1 ? "s" : "", $opt_p, $in, $out,
	   $opt_M ? "Mbit/s" : "kbit/s"
	   );
}
