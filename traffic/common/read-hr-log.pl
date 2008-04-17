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
# Read a single daily log, suck in data, summarize on a
# per-hour basis, calculate peak values for Octet deltas 
# within a single poll interval.
#

# Return data in globals:
#   $count{$v, $h}	Counters per hour for variable $v
#   $max_rate{$v, $h}	Max rate per interval per hour for variable $v
#   $date		Date string of log
#   $ifspeed, $iftype, $ifdescr		As picked from log
#   $sample_delta{$v, $sno}   Delta for counter $v in sample $sno
#   $sample_time{$v, $sno}   Timestamp (hour) for counter $v, sample $sno
#   $max_sample		Maximum sample number for $sample_delta etc.


# Read a single daily log, suck in data.

sub read_log {
    my($fh, $zero_tm) = @_;
    my($h, $m, $s);
    my($v, $dummy);
    my($delta, $delta_time, $delta_rate);
    my($lasttime, $day, $reboot_day, $reboot_time, $last_day);
    my($now, %base, %lasttime);
    my($f1, $f2, $f3, $prev_h, $then_h, $hh);
    my($sample_no, $sno, %sample_no);
    my(@f);
    my($h0_seen) = 0;

    $sample_no = 0;
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

#	print STDERR $_ . "\n";

        ($h, $m, $s) = split(/:/, $f[3]);
        $now = $h * 3600 + $m * 60 + $s;

	# log turnover happens late in hour 23 so that some records can be
	# logged in hour 23 of the previous day.  We need to see the date
	# covering most of the log here...
	if ($h < 23) {
	    $day = $f[0] . " " . $f[1] . " " . $f[2] . " " . $f[4];
	}
	if ($h == 23 && !$h0_seen) {
	    $now -= 24 * 3600;
	    $h -= 24;
	} elsif ($h < 23) {
	    $h0_seen = 1;
	}
	
	# Be careful not to zero counters needlessly.  Check timetamp of
	# reboot more carefully.  This is to work around a bug in Cisco IOS
	# 10.2(2) where you have loopback interfaces configured (ifNumber.0
	# counts them, while "get-next" or "get" of the loopback interface
	# indexes return errors (so my poller will never reset the
	# "rebooted" flag...).
        if (/Reboot/) {
	    if (! defined($lasttime)) { next; } # use next sample as base
	    $reboot_day = $f[7] . " " . $f[8] . " " . $f[9] . " " . $f[11];
	    if ($day ne $reboot_day) { next; } # ignore, reboot too long ago
	    my($hr, $mr, $sr) = split(/:/, $f[10]);
	    $reboot_time = $hr * 3600 + $mr * 60 + $sr;
	    if ($reboot_time < $lasttime &&
		$last_day eq $day)
	    {
		next; # ignore, too long ago
	    }
	    ($hr, $mr, $sr) = split(/:/, $f[3]);
	    my $log_time = $hr * 3600 + $mr * 60 + $sr;
	    if ($reboot_time > $log_time) { next; } # in the future?
            foreach $k (keys %base) {
                $base{$k} = 0;
            }
            next;
        }

        ($v, $dummy) = split(/\./, $f[5]);

        if (!defined($base{$v})) {
            $base{$v} = $f[6];
	    $lasttime{$v} = $now;
	    next;
	}

	$lasttime = $now;
	$last_day = $day;

	if (defined($sample_no{$now})) {
	    $sno = $sample_no{$now};
	} else {
	    $sample_no++;
	    $sample_time{$sample_no} = $now / 3600.0;
	    $sample_no{$now} = $sample_no;
	    $sno = $sample_no;
	}

	$delta = ($f[6] - $base{$v});
	if ($delta < 0 && !($v =~ /ifHC/o)) {
	    $delta += 0xffffffff;
	}

	if ($delta < 0) {	# could be that address moved
	    $delta = 0;		# to another port
	}

#	printf(STDERR "var %s delta %f\n", $v, $delta);

	$sample_delta{$v, $sno} = $delta;
	$sample_time{$v, $sno} = $now / 3600.0;

	$delta_time = $now - $lasttime{$v};
	if (/Octets/) {
	    if ($delta_time > 30) {	# Skip too small intervals (inaccurate)
		$delta_rate = $delta / $delta_time;
		if (!defined($max_rate{$v, $h}) ||
		    $delta_rate > $max_rate{$v, $h})
		{
		    $max_rate{$v, $h} = $delta_rate;
		}
	    }
	}
	if (!defined($count{$v,$h})) {
	    $count{$v,$h} = 0;
	}

	$then_h = &floor_int($lasttime{$v} / 3600);
	if ($lasttime{$v} < 0 && $now > 0) { # previous day, store some in h -1
	    $f1 = ($delta_time - $now) / $delta_time;
	    $count{$v, $then_h} += $delta * $f1;
	    $count{$v, $h} += $delta * $now / $delta_time;
#	    print STDERR "day rollover\n";
	} elsif ($h == $then_h) { # Normal, both in same hour
#	    print STDERR "both in same hour\n";
	    $count{$v, $h} += $delta;
	} elsif ($h == ($then_h + 1)) { # contiguous log, distribute
#	    print STDERR "hour rollover $then_h -> $h\n";
	    $f1 = (3600 - ($lasttime{$v} - $then_h * 3600)) / $delta_time;
	    $f2 = 1.0 - $f1;
	    $prev_h = sprintf("%02d", $h-1);
	    if (!defined($count{$v, $prev_h})) {
		$count{$v, $prev_h} = 0;
	    }
	    $count{$v, $prev_h} += $delta * $f1;
	    $count{$v, $h} += $delta * $f2;
	} else {		# Non-contiguous log, distribute
#	    print STDERR "non-contiguous hour rollover $then_h -> $h\n";
	    $f1 = (3600 - ($lasttime{$v} - $then_h * 3600)) / $delta_time;
	    $f3 = ($now - $h * 3600) / $delta_time;
	    $hh = sprintf("%02d", $then_h);
	    $count{$v, $hh} += $delta * $f1;
	    $count{$v, $h} += $delta * $f3;
	    for ($i = $then_h + 1; $i < $h; $i++) {
		$hh = sprintf("%02d", $i);
		if (!defined($count{$v, $hh})) {
		    $count{$v, $hh} = 0;
		}
		$count{$v, $hh} += $delta * 3600 / $delta_time;
		# Fake peak values...
		$max_rate{$v, $hh} = $delta / $delta_time;
	    }
	}

	$base{$v} = $f[6];
	$lasttime{$v} = $now;
	if ($sample_no == 10) {
	    $date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
	}
    }
    # Do averaging for the last hour
    if ($m <= 60 - &min(10, ($delta_time * 5)) &&
	$m * 60 + $s != 0) {
	foreach $v (keys %base) {
	    $count{$v, $h} = $count{$v, $h} * 3600.0 / ($m * 60 + $s);
	}
    }

    undef %base;
    undef %lasttime;

    if (!defined($date)) {
	$date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
    }
    $max_sample = $sample_no;
}

1;
