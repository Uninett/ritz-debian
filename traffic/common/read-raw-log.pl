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

#
# Read a single daily log, suck in data, do not summarize
# but just fetch interval values.
#

# Return data in globals:
#   $count{$v, $i}	Delta for counter $v in interval $i
#   $sample_time{$v, $i} Sample time in hrs for counter $v, end of sample $i
#   $date		Date string of log
#   $ifspeed, $iftype, $ifdescr		As picked from log
#   $max_sample		Max number of samples

sub read_log {
    my($fh) = @_;
    my($h, $m, $s, $sample_no);
    my($v, $dummy);
    my($delta, $lasttime, $day, $reboot_day, $reboot_time);
    my($now, %base);
    my($starter);
    my(@f);

    $sample_no = -1;
    while (<$fh>) {
        chop;
	@f = split;
        
        if (/ifSpeed/) {
            $ifspeed = $f[1];
            next;
        }
        if (/ifType/) {
            $iftype = $f[1];
            next;
        }
        if (/ifDescr/) {
            $ifdescr = $f[1];
            $ifdescr =~ s/^"//;  # "
            $ifdescr =~ s/"$//;  # "
            next;
        }

        ($h, $m, $s) = split(/:/, $f[3]);
        $now = $h * 3600 + $m * 60 + $s;

	# log turnover happens late in hour 23 so that some records can be
	# logged in hour 23 of the previous day.  We need to see the date
	# covering most of the log here...
	if ($h < 23) {
	    $day = $f[0] . " " . $f[1] . " " . $f[2];
	}
	
	# Be careful not to zero counters needlessly.  Check timetamp of
	# reboot more carefully.  This is to work around a bug in Cisco IOS
	# 10.2(2) where you have loopback interfaces configured (ifNumber.0
	# shows them, while "get-next" or "get" of the loopback interface
	# indexes return errors (so my poller will never reset the
	# "rebooted" flag...).
        if (/Reboot/) {
	    if (! defined($lasttime)) { next; } # use next sample as base
	    $reboot_day = $f[7] . " " . $f[8] . " " . $f[9];
	    if ($day ne $reboot_day) { next; } # ignore, reboot too long ago
	    ($h, $m, $s) = split(/:/, $f[10]);
	    $reboot_time = $h * 3600 + $m * 60 + $s;
	    if ($reboot_time < $lasttime) { next; } # ignore, too long ago
            foreach $k (keys %base) {
                $base{$k} = 0;
            }
            next;
        }

        ($v, $dummy) = split(/\./, $f[5]);

	if ($lasttime != $now || defined($count{$v, $sample_no})) {
	    $sample_no++;
	    $sample_time{$sample_no} = $now / 3600.0;
	}

	$lasttime = $now;

        if (!defined($base{$v})) {
            $base{$v} = $f[6];
        } else {
            $delta = ($f[6] - $base{$v});
            if ($delta < 0) {
                $delta += 0xffffffff;
            }

            $count{$v, $sample_no} = $delta;
	    $sample_time{$v, $sample_no} = $now / 3600.0;

            $base{$v} = $f[6];
            if ($sample_no == 10) {
                $date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
            }
        }
    }
    if (!defined $date) {
	$date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
    }
    $max_sample = $sample_no;
}

1;
