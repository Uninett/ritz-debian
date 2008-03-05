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


# Utility routines


# Maximum of inputs

sub max {
    my(@list) = @_;
    my($max, $i);

    foreach $i (@list) {
	if (!defined $max) {
	    $max = $i;
	    next;
	}
	if (!defined $i) { next; }
	if ($i > $max) {
	    $max = $i;
	}
    }
    return $max;
}

# Minimum of inputs

sub min {
    my(@l) = @_;
    my($min, $i);

    foreach $i (@l) {
	if (!defined($min)) {
	    $min = $i;
	    next;
	}
	if (!defined $i) { next; }
	if ($i < $min) {
	    $min = $i;
	}
    }
    return $min;
}

# Return closest lower integer value
# (rounds to lower value when negative, so that -0.5 returns -1)

sub floor_int {
    my($v) = @_;

    if ($v < 0) {
	$v -= 0.99999999999999;	# close enough
    }
    return int($v);
}

# Return n'th percentile among values

sub percentile {
    my($perc, @values) = @_;
    my(@sv) = sort {$a <=> $b} @values;
    my($i);

    $i = int($#sv * $perc / 100);
    return $sv[$i];
}

# Return a suitable variable to compute input octet values with
# Prefer 64-bit counters if present

sub octets_var {
    my($dir) = @_;
    my($i);

    if ($dir eq "in") {
	for ($i = 0; $i <= 5000; $i++) {
	    if (defined($sample_time{"ifHCInOctets",$i})) {
		return "ifHCInOctets";
	    }
	}
	return "ifInOctets";
    } else {
	for ($i = 0; $i <= 5000; $i++) {
	    if (defined($sample_time{"ifHCOutOctets",$i})) {
		return "ifHCOutOctets";
	    }
	}
	return "ifOutOctets";
    }
}

# Given a variable, return array of consecutive "per second"
# values from recently read sample data.

sub sample_val_ps {
    my($var) = @_;
    my(@array, $i, $dt, $dr);

    for ($i = 1; $i <= $max_sample; $i++) {
	if (defined($sample_delta{$var, $i}) &&
	    defined($sample_time{$var, $i-1}) &&
	    defined($sample_time{$var, $i}))
	{
	    $dt = ($sample_time{$var, $i} - $sample_time{$var, $i-1}) * 3600.0;
	    $dr = $sample_delta{$var, $i} / $dt;
	    push(@array, $dr);
	}
    }
    return @array;
}

# Return list of files in a directory

sub directory_files {
    my($d) = @_;
    my($e);
    my($f, @flist);

    opendir(D, $d) || return undef;
    while ($e = readdir(D)) {
	$f = $d . "/" . $e;
	if ( -f $f ) {
	    push(@flist, $e);
	}
    }
    closedir(D);
    return @flist;
}

# Return modification time of a given file

sub modtime {
    my($f) = @_;
    my(@r);

    (@r = stat($f)) || return undef;
    return $r[9];
}

# Return a "nicely formatted percentage" within 4 spaces

sub nice_sprint_perc_4 {
    my($v) = @_;

    if ($v >= 10) {
	return sprintf("%4.1f", $v);
    }
    return sprintf("%4.2f", $v);
}

# Return a "nicely formatted percentage" within 5 spaces

sub nice_sprint_perc_5 {
    my($v) = @_;

    if ($v >= 10) {
	return sprintf("%5.2f", $v);
    }
    return sprintf("%5.3f", $v);
}

# Check validity of arguments, match against regexp given as first arg.
# Return 'undef' on success and index into args pointing to first
# invalid argument if failure.  Note that returning '0' is a failure here,
# so the caller needs to check with defined().

sub invalid_arg {
    my($pat, @args) = @_;
    my($a, $i);
    
    for ($i = 0; $i <= $#args; $i++) {
	$a = $args[$i];
	if (! defined($a)) { next; } # undefined args are OK
	if ($a !~ /^$pat$/) { return $i; }
    }
    return undef;
}

1;
