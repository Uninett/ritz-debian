#
# $Id$
#

# Copyright (c) 2002
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
# Add up data for a number of lines (useful when doing e.g. load-
# sharing), and average measurements over 5-minute intervals.
#

# Return data in globals:
#   $count{$v,$i}	Delta for counter $v in interval $i
#   $base{$v}		Convenience tester for existence of variable in data
#   $sample_time{$v,$i}	Sample time in hrs for counter $v, end of sample $i
#   $sample_time{$i}	Sample time in hrs for end of sample $i
#   $date		Date string of log
#   $ifspeed, $iftype, $ifdescr	   $ifspeed is sum of capacity
#   $max_sample		Max number of samples
#

push(@INC, "%LIBDIR%");

require 'read-raw-log.pl';


sub read_5m_sum {
    my($lines, $date) = @_;
    my(@lines) = split(/\+/, $lines);
    my($line, $base, $cat, $f, $v);
    my($tick, $tt, $lasttick, $ltt, $sno, $f1, $k);
    my($err) = "";
    my(%mycount, %mybase, %mysample_time, $myspeed, $my_max_sample);

    undef %base;
    $myspeed = 0;

    foreach $line (@lines) {
	if (! defined($base = &name_to_file($line, $date))) {
	    $err .= "Could not find base file name for $line / $date\n";
	    next;
	}
	($cat, $f) = &find_cat_and_file($base, $date);
	if (! defined($f)) {
	    $err .= "Could not find data file for $base / $date\n";
	    next;
	}
	open(DAYLOG, "$cat $f |") ||
	    die "Could not open \"$cat $f\": $!\n";
	&read_log(DAYLOG);
	close(DAYLOG);

	foreach $v (keys %base) {
	    $mybase{$v} = $base{$v};

	    $sno = 1;
	    $lasttime{$v} = $sample_time{0};
	    $lasttick = &floor_int($lasttime{$v} * 60/5.0);

	    for ($tick = &floor_int($sample_time{1} * 60/5.0);
		 $tick < 24 * 60/5;
		 $tick++)
	    {
		$tt = $tick * 5.0/60;
		$mysample_time{$v,$tick} = $tt;
		$mysample_time{$tick} = $tt;

		$ltt = $lasttick * 5.0/60;

		if (! defined($mycount{$v,$tick})) {
		    $mycount{$v,$tick} = 0;
		}
		# First include remainder of last sample in this tick
		if ($tt > $sample_time{$sno}) {
		    $f1 = ($sample_time{$sno} - $ltt) /
			($sample_time{$sno} - $lasttime{$v});
		    $mycount{$v,$tick} += $count{$v,$sno} * $f1;
		}
		# ...then include any full samples in this tick
		while ($tt > $sample_time{$sno} && $sno <= $max_sample) {
		    $lasttime{$v} = $sample_time{$sno};
		    $sno++;
		    if ($sample_time{$sno} < $tt) {
			$mycount{$v,$tick} += $count{$v,$sno};
		    }
		}
		# ...and add any remaining partial sample in this tick
		$f1 = ($tt - &max($ltt, $lasttime{$v})) /
		    ($sample_time{$sno} - $lasttime{$v});
		$mycount{$v,$tick} += $count{$v,$sno} * $f1;
		$lasttick = $my_max_sample = $tick;
	    }
	}
	$myspeed += $ifspeed;

	# Tidy up for new round/line
	undef %count;
	undef %base;
	undef %sample_time;
	undef $max_sample;
    }

    # Copy data into expected globals
    foreach $k (keys %mycount) {
	$count{$k} = $mycount{$k};
    }
    foreach $k (keys %mybase) {
	$base{$k} = $mybase{$k};
    }
    foreach $k (keys %mysample_time) {
	$sample_time{$k} = $mysample_time{$k};
    }
    $max_sample = $my_max_sample;
    $ifspeed = $myspeed;

    return $err;
}
