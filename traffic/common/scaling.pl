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


# Calculate autoscaled "nice" max value
#
# Call maxit(v) with each value
# max_scale() returns a nice max value for autoscaling

package scaling;

sub main::maxit {
    my($value) = @_;
    our($max_value);

    if (!defined($max_value) ||
	$value > $max_value)
    {
	$max_value = $value;
    }
}

sub main::max_scale {
    my($log10, $limit, $upper, $bound);
    our($max_value);
    
    if (defined($max_value) &&
	$max_value > 0)
    {
	$log10 = log($max_value) / log(10);
	$limit = int($log10 + 1);
	$upper = exp($limit * log(10));
	if ($max_value < $upper / 8) {
	    $bound = $upper / 8;
	} elsif ($max_value < $upper / 4) {
	    $bound = $upper / 4;
	} elsif ($max_value < $upper / 2) {
	    $bound = $upper / 2;
	} else {
	    $bound = $upper;
	}
    } else {
	$bound = 0.0001;
    }
    return $bound;
}

# Given an interface speed in bit/s,
# return a string which pretty-prints the value and unit
sub main::pretty_ifspeed {
    my($ifspeed) = @_;
    my($scale, $val, $unit);

    ($scale, $unit) = &main::scale_kbit_values($ifspeed / 1000.0);

    $val = $ifspeed / 1000.0 / $scale;

    # is value integral?
    if ($val == int($val)) {
	return sprintf("%d %s", $val, $unit);
    } else {
	return sprintf("%3.2f %s", $val, $unit);
    }
}

sub main::scale_kbit_values {
    my($max) = @_;
    my($log10, $scale, $unit);

    $max *= 1000.0;		# get bit/s

    $log10 = log($max) / log(10);
    $log10 += 0.001;		# compensate possible rounding error

    if ($log10 >= 9) {
	$scale = 1000000.0;
	$unit = "Gbit/s";
    } elsif ($log10 >= 6) {
	$scale = 1000.0;
	$unit = "Mbit/s";
    } elsif ($log10 >= 3) {
	$scale = 1.0;
	$unit = "kbit/s";
    } else {
	$scale = 0.001;
	$unit = "bit/s";
    }
    return ($scale, $unit);
}

1;
