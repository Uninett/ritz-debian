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
# Times are hours in offset from 00:00 local time

# Return data in globals:
#   $count{$v, $i}	Delta for counter $v in interval $i
#   $base{$v}		Convenient tester for existence of variable in log
#			Also used to compute delta for each interval/sample
#   $sample_time{$v, $i} Sample time in hrs for counter $v, end of sample $i
#   $sample_time{$i}	Sample time in hrs for end of sample $i
#                       offset from the start of the log
#   $firsttime{$v}      The first time in hrs counter $v is seen in the log
#   $date		Date string of log
#   $ifspeed, $iftype, $ifdescr		As picked from log
#   $max_sample		Max number of samples
#   $lasttime{$v}       Last sample time for counter $v
#   $dstcomp{$v}        Daylight savings time compensation for counter $v

use Time::Local;
use Date::Parse;

sub read_log {
    my($fh, $disable_23_handling) = @_;
    my($h, $m, $s, $sample_no, %sample_no, $sno);
    my($v, $dummy);
    my($delta, $lasttime, $day, $reboot_day, $reboot_time);
    my($now, $dstcomp, %dstcomp);
    my($starter);
    my(@f);
    my($h0_seen) = 0;
    my(%data_seen, %lasttime_uncomp);
    our(%count, %base, %sample_time);
    our(%lasttime, %firsttime);
    our($date, $ifspeed, $iftype, $ifdescr, $max_sample);

    $dstcomp = 0;
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
	# Some extra robustness
	if (!defined($m) || !defined($s)) { next; }

        $now = $h * 3600 + $m * 60 + $s;

	if (!defined($disable_23_handling)) {
	    # log turnover happens late in hour 23 so that some records can be
	    # logged in hour 23 of the previous day.  We need to see the date
	    # covering most of the log here...
	    if ($h < 23) {
		$day = $f[0] . " " . $f[1] . " " . $f[2];
	    }
	    if ($h == 23 && !$h0_seen) {
		$now -= 24 * 3600;
	    } elsif ($h < 23) {
		if ( ! $h0_seen ) {
		    # Is this day switching to or from daylight savings time?
		    # (executed only once)
		    my($t0, $t1);
		    $t0 = timelocal(strptime(sprintf("%s %s %s 00:00:00",
						     $f[1], $f[2], $f[4])));
		    $t1 = timelocal(strptime(sprintf("%s %s %s 23:30:00",
						     $f[1], $f[2], $f[4])));
		    my($diff) = $t1 - $t0;
		    if ($diff < 23 * 3600) {
			$dstcomp = (-3600);
		    }
		    if ($diff > 24 * 3600) {
			$dstcomp = 3600;
		    }
		}
		$h0_seen = 1;
	    }
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
	    ($h, $m, $s) = split(/:/, $f[3]);
	    my $log_time = $h * 3600 + $m * 60 + $s;
	    if ($reboot_time < $lasttime) { next; } # ignore, too long ago
	    if ($reboot_time > $log_time) { next; } # in the future?
            foreach $k (keys %base) {
                $base{$k} = 0;
            }
            next;
        }

        ($v, $dummy) = split(/\./, $f[5]);

	if (!defined($data_seen{$v})) {
	    if (defined($lasttime{$v})) {
		$firsttime{$v} = $lasttime{$v} / 3600.0;
	    } else {
		$firsttime{$v} = $now / 3600.0;
	    }
	    $data_seen{$v} = 1;
	}
	if (!defined($base{$v})) {
	    $base{$v} = $f[6];
	    $lasttime{$v} = $now;
	    $dstcomp{$v} = 0;
	    next;
	}

	# old "compressed" logs appear to have a single
	# "stray" sample which goes back in time when shifting
	# from daylight savings time.  Trigger DST compensation
	# based on this
	if (defined($lasttime_uncomp{$v})) {
	    my $delta_t = $now - $lasttime_uncomp{$v};
	    if ($delta_t < 0) {
		foreach my $k (keys %base) {
		    $dstcomp{$k} = $dstcomp;
		}
		next;
	    }
	}

	# switch to or from daylight savings time?
	# Note, this only compensates if the data file hasn't
	# already been "fixed".
	if ($dstcomp != 0 &&
	    (($lasttime{$v} > $now) ||
	     ($now - $lasttime{$v} > 3600)))
	{
	    $dstcomp{$v} = $dstcomp;
	}

	$now += $dstcomp{$v};

	if (defined($sample_no{$now})) {
	    $sno = $sample_no{$now};
	} else {
	    $sample_no++;
	    $sample_time{$sample_no} = $now / 3600.0;
	    $sample_no{$now} = $sample_no;
	    $sno = $sample_no;
	}

	$lasttime = $now;
	$lasttime{$v} = $now;
	$lasttime_uncomp{$v} = $now - $dstcomp{$v};

	$delta = ($f[6] - $base{$v});
	if ($delta < 0 && !($v =~ /ifHC/o)) {
	    $delta += 0xffffffff;
	}
	if ($delta < 0) {	# could be that address moved
	    $delta = 0;		# to another port
	}

	$count{$v,$sno} = $delta;
	$sample_time{$v,$sno} = $now / 3600.0;

	$base{$v} = $f[6];
	if ($sample_no == 10 && $h0_seen) {
	    $date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
	}
    }
    foreach my $k (keys %firsttime) {
	# Handle day rollover
	if ($h0_seen && $firsttime{$k} > 23) {
	    $firsttime{$k} -= 24;
	}
    }
    
    if (!defined $date) {
	$date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
    }
    $max_sample = $sample_no;
}

1;
