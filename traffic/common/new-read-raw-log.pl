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
# Read a single daily log, suck in data, do not summarize
# but just fetch interval values.  This variant accepts raw
# data files with seconds UTC since 1 jan 1970 as time entry
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
#   $lasttime{$v}       Last sample time for counter $v (here in secs UTC)

use Date::Format;

use strict;

sub new_read_log {
    my($fh, $zero_tm, $td) = @_;
    my($seekable) = 1;		# start out an optimist
    my(%data_seen, %sample_no, %instance);
    my($pos, $sno, $upto_s, $lasttime, $sample_no);
    my($v, $instance);
    my($date_set, $secs);

    our(%count, %base, %sample_time, %firsttime, %lasttime);
    our($date, $ifspeed, $iftype, $ifdescr, $max_sample);

    if (!defined($zero_tm)) {
	die "new_read_log: zero_tm argument not defined";
    }
    
    if (defined($td)) {
	$upto_s = $^T - $td;
    }

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
	split;

	if (/^Version/o) {
	    if ($_[1] != 1) {
		die "Unrecognized version number for data files: $_[1]";
	    }
	    next;
	}
	if (/^if/) {
	    if (/ifSpeed/) {
		$ifspeed = $_[1];
		next;
	    }
	    if (/ifType/) {
		$iftype = $_[1];
		next;
	    }
	    if (/ifDescr/) {
		$ifdescr = $_[1];
		$ifdescr =~ s/^"//;  # "
		$ifdescr =~ s/"$//;  # "
		next;
	    }
	}

	if ($_[0] !~ /[0-9]+/o) {
	    printf(STDERR
		   "new_read_log: timestamp not numeric -- not new-format log?");
	    printf(STDERR "line: %s\n", $_);
	    exit(1);
	}

	$secs = $_[0];
	my($secs_0) = $secs - $zero_tm;
	my($dec_h0) = $secs_0 / 3600.0;

	# Be careful not to zero counters needlessly.  Check timetamp of
	# reboot more carefully.  This is to work around a bug in Cisco IOS
	# 10.2(2) where you have loopback interfaces configured (ifNumber.0
	# shows them, while "get-next" or "get" of the loopback interface
	# indexes return errors (so my poller will never reset the
	# "rebooted" flag...).
	if (/Reboot/) {
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

	if (!defined($data_seen{$v})) {
	    if (defined($lasttime{$v})) {
		$firsttime{$v} = ($lasttime{$v} - $zero_tm) / 3600.0;
	    } else {
		$firsttime{$v} = $dec_h0;
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
	    $base{$v} = $_[2];
	    $lasttime{$v} = $secs;
	    $instance{$v} = $instance;
	    next;
	}
	$instance{$v} = $instance;
	
	# if we're re-reading the log after log rotation
	# and compression in "tail" mode...
	if (defined($lasttime{$v}) && $lasttime{$v} > $secs) {
	    next;
	}

	if (defined($td)) {
	    if ($secs > $upto_s) {
		if ($seekable) {
		    # Revert to last known position below mark
		    seek($fh, $pos, "SEEK_SET");
		}
		last loop;
	    }
	}

	# Now we've committed to accumulate the sample
	
	if (defined($sample_no{$secs_0})) {
	    $sno = $sample_no{$secs_0};
	} else {
	    $sample_no++;
	    $sample_time{$sample_no} = $dec_h0;
	    $sample_no{$secs_0} = $sample_no;
	    $sno = $sample_no;
	}

	$lasttime = $secs;
	$lasttime{$v} = $secs;

	my $delta = ($_[2] - $base{$v});
	if ($delta < 0 && !($v =~ /ifHC/o)) {
	    $delta += 0xffffffff;
	}
	if ($delta < 0) {	# could be that address moved
	    $delta = 0;		# to another port
	}

	$count{$v,$sno} = $delta;
	$sample_time{$v,$sno} = $dec_h0;
	
	$base{$v} = $_[2];

	if (!$date_set && $secs_0 > 0 && $secs_0 < 24*3600) {
	    my(@lt) = localtime($secs);
	    $date = strftime("%a %d %b %Y", @lt);
	    $date_set = 1;
	}
	if ($seekable && defined($td)) {
	    $pos = tell($fh);
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
