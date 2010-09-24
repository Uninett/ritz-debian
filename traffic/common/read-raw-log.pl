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
use Date::Format;

push(@INC, "%LIBDIR%");

require 'new-read-raw-log.pl';


sub read_log {
    my($fh, $zero_tm, $td) = @_;
    my($h, $m, $s, $sample_no, %sample_no, $sno);
    my($v, $instance, %instance);
    my($delta, $lasttime, $day, $reboot_day, $reboot_time);
    my($now, $dstcomp);
    my($starter);
    my(@f);
    my($computed_dst) = 0;
    my(%data_seen, $lasttime_uncomp);
    my($skip_h);
    our(%count, %base, %sample_time);
    our(%lasttime, %firsttime, %dstcomp);
    our($date, $date_set, $ifspeed, $iftype, $ifdescr, $max_sample);
    my($pos, $seekable);
    my($upto_s, $upto_day);
    my($first_tm, $first_day, $lasttime_comp, $day_comp, $date_now);
    my($was_dst) = 0;
    my($was_comp);

    $date_set = 0;

    if (defined($td)) {
	my($upto_t);
	my($s, $m, $h, $md, $m, $y, $wd, $yd, $dst);
	my($t0);
	my(@a);

	$upto_t = $^T - $td;
	($s, $m, $h, $md, $m, $y, $wd, $yd, $dst) = localtime($upto_t);
	@a = ($s, $m, $h, $md, $m, $y, $wd);
	$upto_day = strftime("%a %b %d", @a);
	$t0 = timelocal(0, 0, 0, $md, $m, $y);
	$upto_s = $upto_t - $t0; # this means "after DST compensation"
    }
    $seekable = 1;		# always the optimist...

    undef $day_comp;
    $dstcomp = 0;
    $sample_no = -1;
    if (defined($td)) {
	$pos = tell($fh);
	if ($pos == -1) {
	    $seekable = 0;	# didn't work out after all
	}
    }

  loop:
    while (<$fh>) {
        chop;
	@f = split;
        
	if (/^Version 1/o) {
	    return &new_read_log($fh, $zero_tm, $td);
	}
	if (/^[0-9]/) {		# Another signal we're doing the new version
	    if ($seekable) {
		seek($fh, $pos, SEEK_SET);
	    }
	    return &new_read_log($fh, $zero_tm, $td);
	}
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

	$day = join(" ", @f[0..2]);

	$date_now = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);

	if (!defined($first_tm)) {
	    $first_tm = timelocal(strptime(sprintf("%s %s %s %02d:%02d:%02d",
						   $f[1], $f[2], $f[4],
						   $h, $m, $s)));
	    $first_day = join(" ", @f[0..2]);
	}

	# log turnover happens late in hour 23 so that some records can be
	# logged in hour 23 of the previous day.  We need to see the date
	# covering most of the log here...
	if (!$computed_dst) {
	    # Is this day switching to or from daylight savings time?
	    my($t0, $t1);
	    $t0 = timelocal(strptime(sprintf("%s %s %s 00:00:00",
					     $f[1], $f[2], $f[4])));
	    $t1 = timelocal(strptime(sprintf("%s %s %s 23:30:00",
					     $f[1], $f[2], $f[4])));
	    my($diff) = $t1 - $t0;
	    if ($diff < 23 * 3600) {
		$dstcomp = (-3600); # switch to daylight savings time
	    } elsif ($diff > 24 * 3600) {
		$dstcomp = 3600; # switch back to normal local time
	    } else {
		foreach my $k (keys %dstcomp) {
		    if ($dstcomp{$k} != 0) {
			$was_dst = 1;
			$was_comp = $dstcomp{$k};
		    }
		    $dstcomp{$k} = 0; # Not a switch-over day, reset to 0.
		}
	    }
	    # Possibly recompute later, when/if we see hour 0
	    if ($h != 23) {
		$computed_dst = 1;
	    }
	}

	# When $day_comp is set to 0, skip this test
	if ((!defined($day_comp) || $day_comp != 0) &&
	    ($first_tm < $zero_tm && $day eq $first_day))
	{
	    $day_comp = -24 * 3600;
	} else {
	    $day_comp = 0;
	}

	$now += $day_comp;

	my($largest_lasttime);
	foreach my $k (keys %lasttime) {
	    if (!defined($largest_lasttime) ||
		$lasttime{$k} > $largest_lasttime)
	    {
		$largest_lasttime = $lasttime{$k};
	    }
	}

	if (!defined($lasttime_comp) &&
	    (($date_now ne $date) ||
	     ($first_tm < $zero_tm) ||
	     ($largest_lasttime >= 23*3600 && $now < 1800)
	    )) # an indication we wrapped to next day
	{
	    $lasttime_comp = 1;
	    foreach my $k (keys %lasttime) {
		if ($lasttime{$k} > 23*3600) {
		    $lasttime{$k} -= 24*3600;
		}
		if ($was_dst) {
		    $lasttime{$k} -= $was_comp;
		}
	    }
	}
	
	# Be careful not to zero counters needlessly.  Check timetamp of
	# reboot more carefully.  This is to work around a bug in Cisco IOS
	# 10.2(2) where you have loopback interfaces configured (ifNumber.0
	# shows them, while "get-next" or "get" of the loopback interface
	# indexes return errors (so my poller will never reset the
	# "rebooted" flag...).
        if (/Reboot/) {
	    $reboot_day = $f[7] . " " . $f[8] . " " . $f[9];
	    if ($day ne $reboot_day) { next; } # ignore, reboot too long ago
	    ($h, $m, $s) = split(/:/, $f[10]);
	    $reboot_time = $h * 3600 + $m * 60 + $s;
	    ($h, $m, $s) = split(/:/, $f[3]);
	    my $log_time = $h * 3600 + $m * 60 + $s;
	    if (defined($lasttime) &&
		$reboot_time < $lasttime)
	    {
		next;	        # ignore, too long ago
	    }
	    if ($reboot_time > $log_time) { next; } # in the future?
            foreach $k (keys %base) {
                $base{$k} = undef;
            }
            next;
        }

        ($v, $instance) = split(/\./, $f[5]);

	if (!defined($data_seen{$v})) {
	    if (defined($lasttime{$v})) {
		$firsttime{$v} = $lasttime{$v} / 3600.0;
	    } else {
		$firsttime{$v} = $now / 3600.0;
	    }
	    $data_seen{$v} = 1;
	}

	# If we change instance for this variable, use current
	# value as a baseline, and skip to next line.
	# Do the same if we have not seen any data yet, or
	# if the management agent re-initialized (rebooted or
	# the sysUpTime.0 counter wrapped).
	if ((defined($instance{$v}) && $instance{$v} != $instance) ||
	    !defined($base{$v})) {
	    $base{$v} = $f[6];
	    $lasttime{$v} = $now;
	    $dstcomp{$v} = 0;
	    $instance{$v} = $instance;
	    next;
	}
	$instance{$v} = $instance;

	# switch to or from daylight savings time?
	# Note, this only compensates if the data file hasn't
	# already been "fixed".
	if ($dstcomp != 0 &&
	    (abs($now - $lasttime_uncomp) > 3000 &&
	     abs($now - $lasttime_uncomp) < 7200))
	{
	    foreach my $k (keys %base) {
		$dstcomp{$k} = $dstcomp;
	    }
	}

	$lasttime_uncomp = $now;
	$now += $dstcomp{$v};

	# if we're re-reading the log after log rotation
	# and compression in "tail" mode...
	if (defined($lasttime{$v}) && $lasttime{$v} > $now) {
	    next;
	}

	if (defined($td)) {
	    if ($now > $upto_s &&
		$day eq $upto_day)
	    {
		if ($seekable) {
		    # Revert to last known position below mark
		    seek($fh, $pos, SEEK_SET);
		}
		last loop;
	    }
	}

	# Now we've committed to accumulate the sample

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
	if (!$date_set && $now > 0 && $now < 24*3600) {
	    $date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
	    $date_set = 1;
	}
	if ($seekable && defined($td)) {
	    $pos = tell($fh);
	}
    }
    if (!defined $date) {
	$date = sprintf("%s %02d %s %4d", $f[0], $f[2], $f[1], $f[4]);
    }
    
    $max_sample = $sample_no;
}

1;
