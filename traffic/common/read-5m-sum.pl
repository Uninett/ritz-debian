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
#   $date		Date string of log, also input to detect "same date"
#   $ifspeed, $iftype, $ifdescr	   $ifspeed is sum of capacity
#   $min_sample		Lowest valid sample index
#   $max_sample		Highest valid sample index
#
#   $position{$base}    Reposition to here, save position at end of file
#   $save_base{$l,$v}   Restore $base{$v} from this, and save afterwards
#   $save_lasttime{$l,$v} Restore $lasttime{$v} from this, and save afterwards
#   $save_varnames{$v}  Used to keep track of variables seen
#

push(@INC, "%LIBDIR%");

require 'read-raw-log.pl';

# Support using name of form "logical-portname:r" to
# reverse packet and byte counters

%rev_ctr = (
    "ifInUcastPkts" => "ifOutUcastPkts",
    "ifInNUcastPkts" => "ifOutNUcastPkts",
    "ifOutUcastPkts" => "ifInUcastPkts",
    "ifOutNUcastPkts" => "ifInNUcastPkts",
    
    "ifInOctets" => "ifOutOctets",
    "ifOutOctets" => "ifInOctets",

    "ifHCInOctets" => "ifHCOutOctets",
    "ifHCOutOctets" => "ifHCInOctets",
    );


sub sprint_hms {
    my($t) = @_;
    my($s, $h, $m, $str);

    $h = int($t);
    $m = int(($t - $h) * 60);
    $s = int(int(($t - $h) * 3600) - ($m * 60));

    $str = sprintf("%02d:%02d:%02d", $h, $m, $s);
    return $str;
}

sub read_5m_sum {
    my($lines, $d, $td) = @_;
    my(@lines) = split(/\+/, $lines);
    my($line, $base, $cat, $f, $v);
    my($tick, $tt, $lasttick, $ltt, $sno, $f1, $k);
    my($err) = "";
    my(%mycount, %mybase, %mysample_time, $myspeed, $my_max_sample);
    our($max_sample, $min_sample);
    my($my_min_sample, $my_max_sample);
    my($reverse, $mv);
    our($ifspeed, $date);
    our(%save_base, %save_lasttime, %save_varnames, %save_ifspeed);
    our(%base, %lasttime, %firsttime, %leftover, %position);
    our(%lastfilebase);
    our(%dstcomp, %save_dstcomp);
    my($seekable) = 0;
    my($end_tick) = 0;
    my($zero_tm, $save_date);
    our($opt_v, $opt_V);

    undef %base;
    undef %count;
    undef %mybase;
    undef %mycount;
    undef %mysample_time;
    undef %sample_time;

    $my_max_sample = 0;
    $myspeed = 0;

    $zero_tm = timelocal(strptime($d));

    $save_date = $date;

    foreach $line (@lines) {
	if ($line =~ /([^:]*):r/) {
	    $line = $1;
	    $reverse = 1;
	} else {
	    $reverse = 0;
	}

	if (! defined($base = &name_to_file($line, $d))) {
	    $err .= "Could not find base file name for $line / $d\n";
	    next;
	}
	($cat, $f) = &find_cat_and_file($base, $d);
	if (! defined($f)) {
	    $err .= "Could not find data file for $base / $d\n";
	    next;
	}

	if (defined($lastfilebase{$line})) {
	    if ($lastfilebase{$line} ne $base) {
		# We switched to another file (and probably instance),
		# so don't try to tie together the ends of the data
		# across the day boundary
		foreach my $v (keys %save_varnames) {
		    undef $save_base{$line,$v};
		    undef $save_lasttime{$line,$v};
		}
	    }
	}
	$lastfilebase{$line} = $base;

#	if ($opt_v) {
#	    printf(STDERR "Processing %s\n", $line);
#	}

	my($date_tm, $date_str, $prev_d);
	if (defined($save_date)) {
	    $date_tm = timelocal(strptime($save_date));
	    $date_str = &tm_to_date($date_tm);
	    $prev_d = &tm_to_date(timelocal(strptime($d)) - 24 * 3600);
	}
	if ($cat eq "cat") {
	    $seekable = 1;
	    if (! open(DAYLOG, $f)) {
		$err .= "Could not open $f\": $!\n";
		next;
	    }
	    if (defined($position{$base})) {
		my($mtime, $size) = (stat(DAYLOG))[9,7];
		my($mod_date) = &tm_to_date($mtime);
		my($pos) = $position{$base};

		if (defined($save_date)) {
		    if ($date_str eq $mod_date) {
			if ($pos < $size) {
			    seek(DAYLOG, $pos, SEEK_SET);
			} elsif ($pos == $size) {
			    close(DAYLOG);
			    next;
			} else {
			    $err .= "File $f shrunk?!?\n";
			    $position{$base} = 0;
			}
		    } else {
			$err .= "$line: date_str != mod_date:";
			$err .= "$date_str vs. $mod_date\n";
			$position{$base} = 0;
		    }
		}
	    }
	} else {
	    if (!open(DAYLOG, "$cat $f |")) {
		$err .= "Could not open \"$cat $f\": $!\n";
		next;
	    }
	}

	if (defined($save_date) && (($date_str eq $d) ||
				    ($date_str eq $prev_d)))
	{
	    # if we saved stuff for this line, restore
	    # to gain an extra (required!) sample,
	    # either at midnight (log rollover) or when
	    # repeatedly looking at data for "today",
	    # but only for those instances(!)
	    if (defined($save_base{$line,"ifInOctets"})) {
		foreach my $v (keys %save_varnames) {
		    $l = $line;
		    if (defined($save_base{$l,$v})) {
			$base{$v} = $save_base{$l,$v};
			$lasttime{$v} = $save_lasttime{$l,$v};
			$dstcomp{$v} = $save_dstcomp{$l,$v};
			# If we're doing old-style data (cheesy test, I know...)
			if ($lasttime{$v} < 48*3600) {
			    # When we compensate for daylight savings change...
			    if ($lasttime{$v} > 24*3600) {
				$lasttime{$v} -= 3600;
			    }
			    if ($date_str eq $prev_d) {
				$lasttime{$v} -= 24 * 3600;
			    }
			}
		    }
		}
	    }
	}

	undef($ifspeed);

	&read_log(DAYLOG, $zero_tm, $td);
	if ($seekable) {
	    $position{$base} = tell(DAYLOG);
	}
	close(DAYLOG);

	if (!defined($ifspeed) && defined($save_ifspeed{$line})) {
	    $ifspeed = $save_ifspeed{$line};
	} elsif (defined($ifspeed)) {
	    $save_ifspeed{$line} = $ifspeed;
	}

	foreach my $v (keys %base) {
	    $save_base{$line,$v} = $base{$v};
	    $save_lasttime{$line,$v} = $lasttime{$v};
	    $save_varnames{$v} = 1;
	    $save_dstcomp{$line,$v} = $dstcomp{$v};
	}

	if ($opt_V) {
	    my($lt, $h, $m, $s);
	    $lt = $lasttime{"ifHCInOctets"};
	    foreach my $v (keys %base) {
		if ($lasttime{$v} > -3600*24 &&
		    ($lasttime{$v} != $lt))
		{
		    printf(STDERR "lasttime diff for %s: %s vs %s (%s)\n",
			   $v, $lt, $lasttime{$v}, $line);
		}
	    }
	    
	    printf(STDERR "lasttime %s for %s\n",
		   &sprint_hms($lt / 3600.0), $line);
	}

	foreach $v (keys %base) {
	    $mybase{$v} = $base{$v};
	    if ($reverse && defined($rev_ctr{$v})) {
		$mv = $rev_ctr{$v};
	    } else {
		$mv = $v;
	    }

	    if (defined($firsttime{$v}) && $firsttime{$v} != $sample_time{0}) {
		if ($firsttime{$v} < -0.25) { # firsttime is in hours...
		    # Could be we changed router/interface
		    # so disregard first sample.  I think.
		    $lasttime{$v} = $sample_time{0};
		    $sno = 1;
		} else {
		    $lasttime{$v} = $firsttime{$v};
		    $sno = 0;
		}
	    } else {
		$lasttime{$v} = $sample_time{0};
		$sno = 1;
	    }

	    $lasttick = &floor_int($lasttime{$v} * 60/5.0);
	    $end_tick = &floor_int($sample_time{$max_sample} * 60/5.0);

	    $min_sample = $lasttick + 1;
	    # Did we actually collect any data?
	    if ($end_tick < $min_sample) {
		next;		# nope, next go-around
	    }

	    if (!defined($my_min_sample)) {
		$my_min_sample = $min_sample;
	    } else {
		$my_min_sample = &min($min_sample, $my_min_sample);
	    }
	    $my_max_sample = &max($my_max_sample, $end_tick);

	    $mysample_time{$lasttick} = $lasttick * 5.0/60;
	    $mysample_time{$mv,$lasttick} = $lasttick * 5.0/60;

	    while(defined($sample_time{$sno}) &&
		  $sample_time{$sno} < $lasttime{$v})
	    {
		# may accidentally have read whole log, but have seen
		# partial data for the day earlier
		$sno++;
	    }

	    if (defined($ifspeed) && $mv =~ /ifHC.*Octets/o) {
		my($s, $r, $dt);

		for($s = $sno; $s <= $max_sample; $s++) {
		    if (!defined($sample_time{$s-1})) { next; }
		    $dt = ($sample_time{$s} - $sample_time{$s-1}) * 3600.0;
		    if ($dt != 0) {
			$r = $count{$mv,$s} * 8 / $dt;
			if ($r > $ifspeed * 1.05) { # Allow 5% overshoot
			    my($e);
			    $e = sprintf("Data rate over ifSpeed: %s vs. %s, " .
					 "name %s file %s date %s time %s\n",
					 $r, $ifspeed,
					 $line, $base, $date,
					 $sample_time{$s});
			    $err .= $e;
			    if ($opt_v) {
				printf(STDERR "%s", $e);
			    }
			    # cap octet counts at interface speed
			    # drop any samples which exceeds
			    $count{$mv,$s} = 0;
			}
		    } # Otherwise hope for the best and leave it alone
		}
	    }

	    if ($opt_V) {
		if ($mv =~ /ifHC.*Octets/) {
		    printf(STDERR
			   "Quantisizing between ticks %d and %d for %s\n",
			   $min_sample, $end_tick, $mv);
		    foreach my $n (0 .. 30) {
			if (defined($sample_time{$sno+$n})) {
			    printf(STDERR "sample_time{%d}: %s, value %s\n",
				   $sno+$n, &sprint_hms($sample_time{$sno+$n}),
				   $count{$mv,$sno+$n}
				);
			}
		    }
		}
	    }

	    for ($tick = $min_sample;
		 $tick <= $end_tick;
		 $lasttick = $tick, $tick++)
	    {
		$tt = $tick * 5.0/60;
		$mysample_time{$mv,$tick} = $tt;
		$mysample_time{$tick} = $tt;

		$ltt = $lasttick * 5.0/60;

		if (! defined($mycount{$mv,$tick})) {
		    $mycount{$mv,$tick} = 0;
		}
		# First any partial sample from previous files
		if ($leftover{$line,$v} != 0) {
		    $mycount{$mv,$tick} += $leftover{$line,$v};
		    $leftover{$line,$v} = 0;
		}
		# Then include remainder of last sample in this tick
		if (defined($sample_time{$v,$sno}) && defined($lasttime{$v}) &&
		    ($sample_time{$v,$sno} != $lasttime{$v}))
		{
		    if ($tt > $sample_time{$v,$sno}) {
			$f1 = ($sample_time{$v,$sno} - $ltt) /
			    ($sample_time{$v,$sno} - $lasttime{$v});
			$mycount{$mv,$tick} += $count{$v,$sno} * $f1;
		    }
		}
		# If no sample for this var, skip ahead
		while (!defined($sample_time{$v,$sno}) && $sno <= $max_sample) {
		    $sno++;
		}
		# ...then include any full samples in this tick
		while ($tt > $sample_time{$v,$sno} && $sno <= $max_sample) {
		    $lasttime{$v} = $sample_time{$v,$sno};
		    $sno++;
		    if ($sample_time{$v,$sno} < $tt) {
			$mycount{$mv,$tick} += $count{$v,$sno};
		    }
		}
		if (defined($sample_time{$v,$sno}) && defined($lasttime{$v}) &&
		    ($sample_time{$v,$sno} != $lasttime{$v}))
		{
		    # ...and add any remaining partial sample in this tick
		    $f1 = ($tt - &max($ltt, $lasttime{$v})) /
			($sample_time{$v,$sno} - $lasttime{$v});
		    $mycount{$mv,$tick} += $count{$v,$sno} * $f1;
		}
	    }
	    $ltt = $lasttick * 5.0/60;
	    while(defined($sample_time{$v,$sno})) {
		if ($ltt > $lasttime{$v}) {
		    $f1 = ($sample_time{$v,$sno} - $ltt) /
			($sample_time{$v,$sno} - $lasttime{$v});
		    $leftover{$line,$v} += $count{$v,$sno} * $f1;
		} else {
		    $leftover{$line,$v} += $count{$v,$sno};
		}
		$lasttime{$v} = $sample_time{$v,$sno};
		$sno++;
	    }
	}
	$myspeed += $ifspeed;

	# Tidy up for new round/line
	undef %count;
	undef %base;
	undef %sample_time;
	undef %firsttime;
	undef %lasttime;
	undef $max_sample;
    }
    # And a final cleanup:
    undef %count;
    undef %base;
    undef %sample_time;
    undef %firsttime;
    undef %lasttime;

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
    $min_sample = $my_min_sample;
    $ifspeed = $myspeed;

#    if ($opt_v) {
#	if ($err ne "") {
#	    printf(STDERR "Returning error string:\n%s", $err);
#	}
#    }

    return $err;
}
