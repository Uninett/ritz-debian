#
# $Id$
#

# Copyright (c) 2010
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

use Date::Format;

use strict;

sub new_read_log {
    my($fh, $zero_tm) = @_;
    my($sample_no) = 0;
    my(%sample_no, %instance, %lasttime);
    my($secs, $secs_0, $dec_h0, $h, $v, $instance, $lasttime);
    my($sno, $v_set);
    my($delta_time, $delta);
    my(%base, $date_set);
    
    our($ifspeed, $iftype, $ifdescr, $date, $max_sample);
    our(%sample_time, %sample_delta, %max_rate, %count);

    while (<$fh>) {
        chop;
	@_ = split;
    
	if (!defined($v_set)) {
	    if (/^Version/o) {
		if ($_[1] != 1) {
		    die "Unrecognized version number for data files: $_[1]";
		}
	    }
	    $v_set = 1;
	}

	if (/^if/o) {
	    if (/^ifSpeed/) {
		$ifspeed = $_[1];
		next;
	    }
	    if (/^ifType/) {
		$iftype = $_[1];
		next;
	    }
	    if (/^ifDescr/) {
		$ifdescr = $_[1];
		$ifdescr =~ s/^"//;  # "
		$ifdescr =~ s/"$//;  # "
		next;
	    }
        }
	
	$secs = $_[0];
	$secs_0 = $secs - $zero_tm;
	$dec_h0 = $secs_0 / 3600.0;
	$h = sprintf("%02d", $dec_h0); # compatibility...

	# Be careful not to zero counters needlessly.  Check timetamp of
	# reboot more carefully.  This is to work around a bug in Cisco IOS
	# 10.2(2) where you have loopback interfaces configured (ifNumber.0
	# shows them, while "get-next" or "get" of the loopback interface
	# indexes return errors (so my poller will never reset the
	# "rebooted" flag...).
	if ($_[1] eq "Reboot") {
	    my $reboot_time = $_[3];
	    if (defined($lasttime) &&
		$reboot_time < $lasttime) # ignore, too long ago
	    {
		next;
	    }
	    if ($reboot_time > $secs) { # in the future?
		next;
	    }
	    # A real reset of the SNMP agent...
	    foreach my $k (keys %base) {
		$base{$k} = undef;
	    }
	    next;
	}

	($v, $instance) = split(/\./, $_[1]);

	# If we change instance for this variable, use current
	# value as a baseline, and skip to next line.
	# Do the same if we have not seen any data yet, or
	# if the management agent re-initialized (rebooted or
	# the sysUpTime.0 counter wrapped).
	if ((defined($instance{$v}) && $instance{$v} != $instance) ||
	    !defined($base{$v})) {
	    $base{$v} = $_[2];
	    $lasttime{$v} = $secs;
	    $instance{$v} = $instance;
	    next;
	}
	$instance{$v} = $instance;
	
	$lasttime = $secs;

	if (defined($sample_no{$secs})) {
	    $sno = $sample_no{$secs};
	} else {
	    $sample_no++;
	    $sample_time{$sample_no} = $dec_h0;
	    $sample_no{$secs} = $sample_no;
	    $sno = $sample_no;
	}

	$delta = ($_[2] - $base{$v});
	if ($delta < 0 && !($v =~ /ifHC/)) {
	    $delta += 0xffffffff;
	}

	if ($delta < 0) {	# could be that address moved
	    $delta = 0;		# to another port
	}
	
	$sample_delta{$v, $sno} = $delta;
	$sample_time{$v, $sno} = $dec_h0;
	
	$delta_time = $secs - $lasttime{$v};

	if (/Octets/) {
	    if ($delta_time > 30) {	# Skip too small intervals (inaccurate)
		my $delta_rate = $delta / $delta_time;

		if ($ifspeed != 0) {
		    if ($delta_rate * 8 > $ifspeed) {
			$delta_rate = 0; # ignore, unreasonable
			$delta = 0;
		    }
		}

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

	my $then_h = &floor_int(($lasttime{$v} - $zero_tm) / 3600);
	if ($secs_0 > 0 && $lasttime{$v} < $zero_tm) {
	    # previous day, store some in h -1
	    my $f1 = ($delta_time - $secs_0) / $delta_time;
	    $count{$v, $then_h} += $delta * $f1;
	    $count{$v, $h} += $delta * $secs_0 / $delta_time;
#	    print STDERR "day rollover\n";
	} elsif ($h == $then_h) { # Normal, both in same hour
#	    print STDERR "both in same hour\n";
	    $count{$v, $h} += $delta;
	} elsif ($h == ($then_h + 1)) { # contiguous log, distribute
#	    print STDERR "hour rollover $then_h -> $h\n";
	    my $f1 = (3600 - (($lasttime{$v} - $zero_tm ) - $then_h * 3600))
		/ $delta_time;
	    my $f2 = 1.0 - $f1;
	    my $prev_h = sprintf("%02d", $h-1);
	    if (!defined($count{$v, $prev_h})) {
		$count{$v, $prev_h} = 0;
	    }
	    $count{$v, $prev_h} += $delta * $f1;
	    $count{$v, $h} += $delta * $f2;
	} else {		# Non-contiguous log, distribute
#	    print STDERR "non-contiguous hour rollover $then_h -> $h\n";
	    my $f1 = (3600 - (($lasttime{$v} - $zero_tm) - $then_h * 3600))
		/ $delta_time;
	    my $f3 = ($secs_0 - $h * 3600) / $delta_time;
	    my $hh = sprintf("%02d", $then_h);
	    $count{$v, $hh} += $delta * $f1;
	    $count{$v, $h} += $delta * $f3;
	    for (my $i = $then_h + 1; $i < $h; $i++) {
		$hh = sprintf("%02d", $i);
		if (!defined($count{$v, $hh})) {
		    $count{$v, $hh} = 0;
		}
		$count{$v, $hh} += $delta * 3600 / $delta_time;
		# Fake peak values...
		$max_rate{$v, $hh} = $delta / $delta_time;
	    }
	}

	$base{$v} = $_[2];
	$lasttime{$v} = $secs;

	if (!$date_set && $secs_0 > 0 && $secs_0 < 24*3600) {
	    my(@lt) = localtime($secs);
	    $date = strftime("%a %d %b %Y", @lt);
	    $date_set = 1;
	}
    }
    if (!defined($date)) {
	my(@lt) = localtime($secs);
	$date = strftime("%a %d %b %Y", @lt);
	$date_set = 1;
    }
    
    $max_sample = $sample_no;
}

1;
