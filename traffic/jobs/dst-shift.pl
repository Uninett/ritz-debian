#! %PERL%
#
# $Id$
#

# Copyright (c) 2001
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

# Process a data file to compensate for the DST shift in the autumn.
# Do this by lying and extending the day to 25 hours.

sub process {
    my(@f);
    my($h, $m, $s, $now, $lasttime, $dst_comp, $h_comp, $h0_seen);

    while (<>) {
	chop;
	@f = split;

	if (/ifSpeed/ || /ifType/ || /ifDescr/) {
	    printf("%s\n", $_);
	    next;
	}
	($h, $m, $s) = split(/:/, $f[3]);
        $now = $h * 3600 + $m * 60 + $s;

	if ($h == 23 && !$h0_seen) {
	    $now -= 24 * 3600;
	} elsif ($h < 23) {
	    $h0_seen = 1;
	}

	if (defined($lasttime) && $dst_comp == 0) {
	    my $td = $now - $lasttime;
	    if ($td < 0) {
		if (abs($td) > (15 * 60)) {
		    $dst_comp = 3600;
		    $h_comp = 1;
		}
	    }
	}
	if ($h == 3 && $dst_comp == 0) {
	    $dst_comp = 3600;
	    $h_comp = 1;
	}
	$now += $dst_comp;
	$h += $h_comp;

	$lasttime = $now;

	printf("%s %s %s %02d:%02d:%02d %s\n",
	       $f[0], $f[1], $f[2], $h, $m, $s, join(' ', @f[4..$#f]));
    }
}

&process();
