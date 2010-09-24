#! %PERL%
#
# $Id$
#

# Copyright (c) 1999, 2000
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

# In some cases several pollers may have been started (yes, that's a
# bug).  This script cleans up a single data file, removing data
# points where either a) the time difference is small (a few seconds)
# and the value for the counter decreases or b) where the data value
# doesn't change.  Especially b) can take care of compressing the raw
# data considerably...


sub process {
    my(@f);
    my($h, $m, $s, $now, $day);
    my($v, $dummy, $delta, $k);
    my($day, $reboot_day, $reboot_time);
    my($now, $lasttime, %lastval, %lasttime, $starter);
    my(%saveline, %saved, %lastline);
    my($old);

    while (<>) {
	chop;
	@f = split;

	if (/ifSpeed/ || /ifType/ || /ifDescr/ || /Version/) {
	    print $_ . "\n";
	    if (/Version 1/) {
		return &new_process();
	    }
	    next;
	}
	if (!defined($old)) {
	    if ($f[0] =~ /^[0-9]/o) {
		return &new_process();
	    } else {
		$old = 1;
	    }
	}

	($h, $m, $s) = split(/:/, $f[3]);
        $now = $h * 3600 + $m * 60 + $s;
	
	if ($h == 23 && !defined($seen_00)) {
	    printf("%s\n", $_);
	    next;
	}
	$seen_00 = 1;
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
		# print all saved lines prior to reboot
		if (defined($lastline{$k})) {
		    printf("%s\n", $lastline{$k});
		    undef $lastline{$k};
		}
		undef $lastval{$k};
            }
	    printf("%s\n", $_);
            next;
        }

	# Make an attempt at compensating for shifts in DST, either
	# when it comes or when it goes away.  Yes, this is lame
	# (should have used UTC), but we have too much collected data
	# in the local time zone to ignore this problem, and I want to
	# get rid of the spikes and stretches which otherwise occur
	# around these events.  This will lead to these days either
	# being 23 og 25 hours.

	if (defined($lasttime) && ($dst_comp == 0)) {
	    $td = $now - $lasttime;
	    if ($td < 0 &&
		abs($td) > (43 * 60) &&	# tolerate up to 15 min poll intv.
		abs($td) < (62 * 60)) # plus some slop
	    {
		$dst_comp = 3600;
	    }
	    if ($td > (43 * 60) &&
		$td < (62 * 60))
	    {
		$dst_comp = -3600;
	    }
	    $now += $dst_comp;
	}

	$lasttime = $now;

	($v, $dummy) = split(/\./, $f[5]);

        if (defined($lastval{$v})) {

	    # time decreasing or same? ignore.
	    if ($lasttime{$v} >= $now) { next; }

	    # value the same?  Print first, save later
	    if ($lastval{$v} == $f[6]) {
		if (! defined($samevalseen{$v})) {
		    # print first with same value to bring
		    # delta($v) = 0.
		    printf("%s\n", $_);
		    $samevalseen{$v} = 1;
		    next;
		}
		# Save later occurrances
		$lastline{$v} = $_;
		next;
	    } else {
		undef $samevalseen{$v};
	    }

	    # time difference less than 5s; ignore (inaccurate)
	    if (($now - $lasttime{$v}) < 5) { next; }

	    # value decreasing by a smallish amount (5s 155Mbit/s octets)
	    if ($lastval{$v} > $f[6] &&
		abs($lastval{$v} - $f[6]) < 100e6 &&
		($now - $lasttime{$v}) <= 5)
	    {
		next;		# ignore
	    }
	}
	if (defined($lastline{$v})) {
	    printf("%s\n", $lastline{$v});
	    undef $lastline{$v};
	}
	$lastval{$v} = $f[6];
	$lasttime{$v} = $now;
	printf("%s\n", $_);
    }
    foreach $v (keys %lastline) {
	if (defined($lastline{$v})) {
	    printf("%s\n", $lastline{$v});
	}
    }
}

sub new_process {
    my($secs);
    my($lasttime, %lastval, %lastline, %instance, %samevalseen);
    my(%kw_vals);

    if (seek(STDIN, 0, 0) != 1) {
	printf(STDERR
	       "new_process: warning: could not seek to position 0, continuing"
	    );
    }
    while(<>) {
	chomp;
	split;

	if (/ifSpeed/ || /ifType/ || /ifDescr/ || /Version/) {
	    my $k = $_[0];
	    my $v = join(' ', @_[1..$#_]);
	    my $p = 0;
	    
	    # eliminate duplicate values
	    if (defined($kw_vals{$k})) {
		if ($kw_vals{$k} ne $v) {
		    $p = 1;
		}
	    } else {
		$p = 1;
	    }
	    $kw_vals{$k} = $v;
	    if ($p) {
		print $_ . "\n";
	    }
	    next;
	}

	$secs = $_[0];

	# handle reboots, possibly undef lastval values
	if (/Reboot/) {
	    if (!defined($lasttime)) {
		print $_ . "\n";
		next;
	    }

	    my $reboot_time = $_[3];
	    if ($reboot_time < $lasttime) {
		print $_ . "\n";
		next; 		# ignore, too long ago
	    }
	    if ($reboot_time > $secs) {
		print $_ . "\n";
		next;		# ignore, in the future
	    }
	    foreach my $k (keys %lastval) {
		# Print all saved lines prior to reboot
		if (defined($lastline{$k})) {
		    print $lastline{$k} . "\n";
		    undef $lastline{$k};
		}
		undef $lastval{$k};
	    }
	    print $_ . "\n";
	    next;
	}

	$lasttime = $secs;

	my($v, $instance) = split(/\./, $_[1]);

	# If the instance changed, can't compare to previous value
	if (defined($instance{$v})) {
	    if ($instance{$v} != $instance) {
		undef $lastval{$v};
	    }
	}
	$instance{$v} = $instance;

	my($value) = $_[2];

	if (defined($lastval{$v})) {

	    # time decreasing or same? ignore.
	    if ($lasttime{$v} >= $secs) { next; }

	    # value the same?  Print first, save later
	    if ($lastval{$v} == $value) {
		if (! defined($samevalseen{$v})) {
		    # print first with same value to bring
		    # delta($v) = 0.
		    print $_ . "\n";
		    $samevalseen{$v} = 1;
		    next;
		}
		# Save later occurrances
		$lastline{$v} = $_;
		next;
	    } else {
		undef $samevalseen{$v};
	    }
	    
	    # time difference less than 5s; ignore (inaccurate)
	    if (($secs - $lasttime{$v}) < 5) { next; }
	    
	    # value decreasing by a smallish amount (5s 155Mbit/s octets)
	    # and interval is small; ignore that as well.  XXX dubious
	    if ($lastval{$v} > $value &&
		abs($lastval{$v} - $f[2]) < 100e6 &&
		($secs - $lasttime{$v}) <= 5)
	    {
		next;		# ignore
	    }
	}
	# if defined, print last saved line
	if (defined($lastline{$v})) {
	    print $lastline{$v} . "\n";
	    undef $lastline{$v};
	}
	$lastval{$v} = $value;
	$lasttime{$v} = $secs;
	print $_ . "\n";
    }
    foreach $v (keys %lastline) {
	if (defined($lastline{$v})) {
	    print $lastline{$v} . "\n";
	}
    }
}

&process();
