# !%PERL%
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

# Show deltas where value changes, as an extra field.

sub process {
    my(@f);
    my($h, $m, $s, $now, $day);
    my($v, $dummy, $delta, $k);
    my($day, $reboot_day, $reboot_time);
    my($now, $lasttime, %lastval, %lasttime, $starter);
    my(%saveline, %saved);

    while (<>) {
	chop;
	@f = split;

	if (/ifSpeed/ || /ifType/ || /ifDescr/) {
	    printf("%s\n", $_);
	    next;
	}
	($h, $m, $s) = split(/:/, $f[3]);
        $now = $h * 3600 + $m * 60 + $s;
	
	if ($h < 23) {
	    $day = $f[0] . " " . $f[1] . " " . $f[2];
	}
	# handle reboots, possibly zero lastval vaules
	if (/Reboot/) {
	    if (!defined($lasttime)) {
		printf("%s\n", $_);
		next;
	    }
	    $reboot_day = $f[7] . " " . $f[8] . " " . $f[9];
	    if ($day ne $reboot_day) {
		printf("%s\n", $_);
		next;
	    } 
	    ($h, $m, $s) = split(/:/, $f[10]);
	    $reboot_time = $h * 3600 + $m * 60 + $s;
	    if ($reboot_time < $lasttime) {
		printf("%s\n", $_);
		next;	# ignore, too long ago
	    }
            foreach $k (keys %lastval) {
                $base{$k} = 0;
            }
	    printf("%s\n", $_);
            next;
        }
	$lasttime = $now;

	($v, $dummy) = split(/\./, $f[5]);

        if (defined($lastval{$v})) {
	    $delta = ($f[6] - $lastval{$v});
	    if ($delta < 0) {
		$delta += 0xffffffff;
	    }
	} else {
	    $delta = "";
	}
	$lastval{$v} = $f[6];
	$lasttime{$v} = $now;
	printf("%s <%s>\n", $_, $delta);
    }
}

&process();
