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
# Date/time handling routines.
# These have evolved over time with no major cleanup.  It shows...
#

# Might save some usecs by precomputing this
$seconds_pr_day = 24*60*60;
$seconds_per_day = $seconds_pr_day;

require 'timelocal.pl';

# Transform either dd, mm-dd or yyyy-mm-dd into yyyymmdd.

sub get_date {
    my($date_str) = @_;
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
    my($today_str);
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
    
    if ($date_str =~ /^(\d\d)$/) {
	return sprintf("%04d%02d%02d", $year+1900, $mon+1, $1);
    }
    if ($date_str =~ /^(\d\d)-(\d\d)$/) {
	return sprintf("%04d%02d%02d", $year+1900, $1, $2);
    }
    if ($date_str =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/) {
	return sprintf("%04d%02d%02d", $1, $2, $3);
    }
    return undef;
}

# return today's date as yyyymmdd

sub today {
    my($yyyy, $mm, $dd);

    ($dd, $mm, $yyyy) = (localtime(time))[3,4,5];
    $mm += 1;
    $yyyy += 1900;
    sprintf("%04d%02d%02d", $yyyy, $mm, $dd);
}

# return yesterday's date as yyyymmdd

sub yesterday {
    my($yyyy, $mm, $dd);
    my($time);

    $time = time - 60*60*24;
    ($dd, $mm, $yyyy) = (localtime($time))[3,4,5];
    $mm += 1;
    $yyyy += 1900;
    sprintf("%04d%02d%02d", $yyyy, $mm, $dd);
}

# Convert a string of form yyyymmdd to a week / year pair (ww / yyyy)

sub date_to_week {
    my($str) = @_;
    my($week, $year, $tm);
    
    if ($str =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	# two hours into day
	$tm = &timelocal(0,2,0,$3,$2-1,$1-1900);
	$week = &weekno($tm);
	return ($week, $1);
    }
    return undef;
}

# Convert a string of form yyyymmdd to a week / year pair (ww / yyyy)
# representing the "previous week".

sub date_to_previous_week {
    my($str) = @_;
    my($week, $year, $tm);

    if ($str =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	# two hours into day
	$tm = &timelocal(0,2,0,$3,$2-1,$1-1900);
	$tm -= 60*60*24*7;
	return &tm_to_week_and_year($tm);
    }
    return undef;
}
    
# convert time_t to yyyymmdd string

sub tm_to_date {
    my($tm) = @_;
    my($dd, $mm, $yy, $dummy);

    ($dummy, $dummy, $dummy, $dd, $mm, $yy, $dummy, $dummy, $dummy) =
	localtime($tm);
    return sprintf("%4d%02d%02d", $yy+1900, $mm+1, $dd);
}

# convert an yyyymmdd string to a time_t (2 hours into day)

sub date_to_tm {
    my($yyyymmdd) = @_;
    my($yy, $mm, $dd, $dummy, $time);

    if ($yyyymmdd =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	$yy = $1 - 1900;
	$mm = $2 - 1;
	$dd = $3;
	$time = &timelocal (0, 0, 2, $dd, $mm, $yy);
    }
    $time;
}
    

# Here, Monday = 0, Sunday = 6

sub wday {
    my($d) = @_;

    @wdays[($d+1)%7];
}

#               J   F   M   A   M   J   J   A   S   O   N   D
@daysinmonth = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
@wdays = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
@months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun",
	   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
$timezone = 1; # Timezone - should be from somewhere else... XXX

sub pretty_date {
    my($yyyymmdd) = @_;
    my($yy, $mm, $dd, $wd, $dummy);
    my($time);

    if ($yyyymmdd =~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	$yy = $1 - 1900;
	$mm = $2 - 1;
	$dd = $3;
	$time = &timelocal (0, 0, 2, $dd, $mm, $yy);
	($dummy, $dummy, $dummy, $dummy,
	 $dummy, $dummy, $wd, $dummy, $dummy) = localtime($time);
	return sprintf("%s %d %s %d",
		       $wdays[$wd],
		       $dd, 
		       $months[$mm],
		       $yy + 1900);
    }
    return $yyyymmdd;
}

# Given a time_t, return (week / year) pair
sub tm_to_week_and_year {
    my($tm) = @_;
    my($year, $weekno, $dummy);

    ($dummy, $dummy, $dummy,
     $dummy, $dummy, $year,
     $dummy, $yday, $dummy) = localtime($tm);
    $weekno = int(($yday - &firstdayfirstweek($year) + 7) / 7);
    ($weekno, $year+1900);
}

# Given a time_t, return (month / year) pair (month: 01 - 12, year: yyyy)

sub tm_to_month_and_year {
    my($tm) = @_;
    my($year, $month, $x);

    ($x, $x, $x, $x, $month, $year, $x, $x, $x) = localtime($tm);
    return ($month + 1, $year + 1900);
}

sub tm_to_mday {
    my($tm) = @_;
    my($md, $x);

    ($x, $x, $x, $md, $x, $x, $x, $x, $x) = localtime($tm);
    return $md;
}

# Given a time_t, return week number

sub weekno {
   my($tm) = @_;
   my($year, $weekno, $dummy);
   ($dummy, $dummy, $dummy,
    $dummy, $dummy, $year,
    $dummy, $yday, $dummy) = localtime($tm);
   $weekno = int(($yday - &firstdayfirstweek($year) + 7) / 7);
   $weekno;
}

# Return first day of week 1 of any year

sub firstdayfirstweek {
   my($y) = @_;
   my($ret);
   # Get time of January 1, 0.0.0.0
   # Note that DST is never in effect on Jan 1...
   my($firsttime) = &timelocal(0, 0, 0, 1, 0, $y);
   my(@firstday) = localtime($firsttime);
   my($wday) = $firstday[6];
   # Rule works for some years.....89 to 92 tested, they all hit branch 2...
   if ($wday > 4) {
      $ret = 8 - $wday;
   } else {
      $ret = 1 - $wday;
   }
   $ret;
}

# Return timevalue for 2 hours into the day
# (to avoid DST troubles). Year = 1900 ->
 
sub firstinweek {
   my($weekno, $year) = @_;
   # 2 hours into this year
   my($time) = &timelocal(0, 0, 2, 1, 0, $year - 1900);
   # Add number of days since start of year
   $time += (($weekno - 1) * 7 +
	     &firstdayfirstweek($year-1900)) * 60 * 60 * 24;
   $time;
}

# This should account for leap-years as well
sub days_in_month {
    my($year, $month) = @_;
    return $daysinmonth[$month-1];
}

# Check and decode a datespec
# A datespec is a '-'-delimited string containing yy[yy]-[mm]-[ww]-[dd]
# Ex.:
# 	96-01 means all of January 1996
#       96--02 means second week of 1996
#       1996-03--28 means 28. march
#       1996-12-11-25 doesn't really make sense, but we'll ignore
#		the week, so this means 25. Dec 1996
#
#		As a special case we'll consider
#       1996-12-11 to be 11. Dec of 1996
#
#	epoch	"The entire epoch since data collection started".
#		In this installation that's %DATASTART%.
#        

# Todo:
#       Should only return no_days up to yesterday, making sure
#       we are not trying to see into the future :-)


sub decode_date_spec {		# This should not be used 
    my($datespec) = @_;		# it will be removed because of
    return (&decode_datespec);	# inconsistent naming
}

sub decode_datespec {
    my($datespec) = @_;
    my($year, $month, $week, $day, $base_tm, $no_days);

    if ($datespec eq "epoch") {
	$base_tm = &date_to_tm(%DATASTART%);
	# Truncation takes care of that this only includes yesterday 
	$no_days = int((time - $base_tm) / (60*60*24));
	return ($base_tm, $no_days);
    }

    if ($datespec !~ /^(\d*)(-(\d*)(-(\d*)(-(\d*))*)*)*$/) {
	return undef;
    }

    ($year, $month, $week, $day) = split('-', $datespec);
    $year = 1900 + $year if ($year < 1900);
    if ($day) {
	$base_tm = &date_to_tm($year . $month . $day);
	$no_days = 1;
    } elsif ($week && $month) {
	# Both week and month doesn't make sense, we'll assume
	# that $week is really meant to be $day
	$base_tm = &date_to_tm($year . $month . $week);
	$no_days = 1;
    } elsif ($week) {
	$base_tm = &firstinweek($week, $year);	
	$no_days = 7;
    } elsif ($month) {
	$base_tm = &date_to_tm($year . $month . "01");
	$no_days = &days_in_month($year, $month);
    } elsif ($year) {
	$base_tm = &date_to_tm($year . "01" . "01");
	$no_days = 365;
    } else {
	return undef;
    }
    return($base_tm, $no_days);
}

# Generate a string suitable for presentation
#
sub pretty_datespec {
    my($datespec) = @_;
    my($year, $month, $week, $day, $base_tm, $no_days);
    my($s, $d);

    if ($datespec eq "epoch") {
	return(sprintf("epoch (since %s)", &pretty_date("%DATASTART%")));
    }

    ($year, $month, $week, $day) = split ('-', $datespec);
    $year = 1900 + $year if  ($year < 1900);
    if ($day) {
	return ($year ."-" . $month . "-" . $day);
    } elsif ($week && $month) {
	# Both week and month doesn't make sense, we'll assume
	# that $week is really meant to be $day
	return ($year ."-" . $month . "-" . $week);
    } elsif ($week) {
	return "week $week in $year";
    } elsif ($month) {
	return "$months[$month -1], $year";
    } elsif ($year) {
	return "$year";
    } else {
	return undef;
    }
}
sub today_spec {
    my($yyyy, $mm, $dd);

    ($dd, $mm, $yyyy) = (localtime(time))[3,4,5];
    $mm += 1;
    $yyyy += 1900;
    sprintf("%04d-%02d--%02d", $yyyy, $mm, $dd);
}

# return yesterday's date as yyyy-mm--dd
sub yesterday_spec {
    my($yyyy, $mm, $dd);
    my($time);

    $time = time - 60*60*24;
    ($dd, $mm, $yyyy) = (localtime($time))[3,4,5];
    $mm += 1;
    $yyyy += 1900;
    sprintf("%04d-%02d--%02d", $yyyy, $mm, $dd);
}

# Make a datespec, given a type (month, week, day) and a value
#
# If value unspecified, use "previous whatever" as default
# ie. previous week, previous month, yesterday 
# Value is a '-'-separated string
# ie. ("week", "12") is 12. week of this year
#     ("week", "") is last week
#     ("day", 1) is 1. day of this month in this year
#     ("day", 11-05, is 5. Nov of this year
sub make_datespec {
    my($type, $val) = @_;
    my($month, $year, $week, $day);

    if ($type eq "epoch") { return "epoch"; }

    if ($type eq "month") {
	($month, $year) = reverse(split('-', $val));
	$year = 1900 + (localtime(time))[5] unless $year;
	# This will break at the turn of the century
	$year += 1900 if ($year < 1900);
	$month = (localtime(time))[4] unless $month;
	if ($month == 0) {
	    $month = 12;
	    $year -= 1;
	}
	return (sprintf("%04d-%02d", $year, $month));

    } elsif ($type eq "year") {
	$year = $val + 0;	# make numeric (?)
	$year = 1900 - 1 + (localtime(time))[5] unless $year;
	$year += 1900 if ($year < 1900);
	return (sprintf("%04d", $year));

    } elsif ($type eq "week") {
	($week, $year) = reverse (split ('-', $val));
	$year = 1900 + (localtime(time))[5] unless $year;
	# This will break at the turn of the century
	$year += 1900 if ($year < 1900);
	($week, $year) = &date_to_previous_week(&today()) unless $week;
	return (sprintf("%04d--%02d", $year, $week));

    } elsif ($type eq "day") {
	($day, $month, $year) = reverse (split ('-', $val));
	$year = 1900 + (localtime(time))[5] unless $year;
	# This will break at the turn of the century
	$year += 1900 if ($year < 1900);
	$month = (localtime(time))[4]+1 unless $month;
	if ($day) {
	    return (sprintf("%04d-%02d--%02d", $year, $month, $day));
	} else {
	    return (&yesterday_spec());
	}
    }
}

# Given a tm, find the day of week as a string ("Mon", ... "Sun")
sub tm_to_day_of_week {
# Set $d to date (1-31), $m to month (1-12), $y to year (e.g. 1994). Then
    my($tm) = @_;
    my($dummy, $wd);

    ($dummy, $dummy, $dummy, $dummy,
     $dummy, $dummy, $wd, $dummy, $dummy) = localtime($tm);
    return($wdays[$wd]);
}


# Convert date in the form of yyyymmdd to a datespec of the specified
# type (either "year", "month", "week" or "day").

sub date_to_datespec {
    my($yyyymmdd, $type) = @_;
    my($year, $month, $day, $week);

    if ($yyyymmdd !~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	return undef;
    }
    $year = $1;
    $month = $2;
    $day = $3;
    if      ($type eq "year") {
	return sprintf("%04d", $year);
    } elsif ($type eq "month") {
	return sprintf("%04d-%02d", $year, $month);
    } elsif ($type eq "week") {
	($week, $year) = &date_to_week($yyyymmdd);
	return sprintf("%04d--%02d", $year, $week);
    } elsif ($type eq "day") {
	return sprintf("%04d-%02d--%02d", $year, $month, $day);
    } 
    return undef;
}

# Return a string with a datespec type (ie. 'day', 'week' etc.)
sub datespec_type {
    my($datespec) = @_;
    my($type, $base_tm, $nodays);
    
    return "epoch" if ($datespec eq "epoch");

    ($base_tm, $nodays) = &decode_datespec($datespec);
    return (undef) unless ($base_tm);
    return ("day") if ($nodays == 1);
    $type = "week" if ($nodays > 1);
    $type = "month" if ($nodays > 7);
    $type = "year" if ($nodays > 31);
    return ($type);
}

# Return the "next datespec" 
sub next_datespec {
    my($datespec) = @_;
    my($year, $month, $week, $day, $base_tm, $no_days);

    if ($datespec eq "epoch") { return undef; }

    ($year, $month, $week, $day) = split('-', $datespec);
    $year = 1900 + $year if ($year < 1900);
    if ($day) {
	$base_tm = &date_to_tm(sprintf("%04d%02d%02d", $year, $month, $day));
	($year, $month, $day) = 
	    unpack("a4a2a2", &tm_to_date($base_tm+(60*60*24))); 
	return (sprintf("%04d-%02d-%02d", $year, $month, $day));
    } elsif ($week && $month) {
	# Both week and month doesn't make sense, we'll assume
	# that $week is really meant to be $day
	$base_tm = &date_to_tm(sprintf("%04d%02d%02d", $year, $month, $week));
	($year, $month, $day) = 
	    unpack("a4a2a2", &tm_to_date($base_tm+(60*60*24))); 
	return (sprintf ("%04d-%02d-%02d", $year, $month, $day));

    } elsif ($week) {
	if ($week >= 52) {
	    $year++;
	    $week=1;
	} else {
	    $week++;
	}	    
	return (sprintf("%04d--%02d", $year, $week));
    } elsif ($month) {
	if ($month >= 12) {
	    $year++;
	    $month=1;
	} else {
	    $month++;
	}	    
	return (sprintf("%04d-%02d", $year, $month));
    } else {
	return (sprintf("%04d", ++$year));
    }
}

# Return the "previous datespec" 
sub previous_datespec {
    my($datespec) = @_;
    my($year, $month, $week, $day, $base_tm, $no_days);

    if ($datespec eq "epoch") { return undef; }

    ($year, $month, $week, $day) = split ('-', $datespec);
    $year = 1900 + $year if  ($year < 1900);
    if ($day) {
	$base_tm = &date_to_tm(sprintf("%04d%02d%02d", $year, $month, $day));
	($year, $month, $day) = 
	    unpack("a4a2a2", &tm_to_date($base_tm-(60*60*24))); 
	return (sprintf ("%04d-%02d-%02d", $year, $month, $day));
    } elsif ($week && $month) {
	# Both week and month doesn't make sense, we'll assume
	# that $week is really meant to be $day
	$base_tm = &date_to_tm(sprintf ("%04d%02d%02d", $year, $month, $week));
	($year, $month, $day) = 
	    unpack("a4a2a2", &tm_to_date($base_tm-(60*60*24))); 
	return (sprintf ("%04d-%02d-%02d", $year, $month, $day));
    } elsif ($week) {
	if ($week <= 1) {
	    $year--;
	    $week=52;
	} else {
	    $week--;
	}	    
	return (sprintf ("%04d--%02d", $year, $week));
    } elsif ($month) {
	if ($month <= 1) {
	    $year--;
	    $month=12;
	} else {
	    $month--;
	}	    
	return (sprintf ("%04d-%02d", $year, $month));
    } else {
	return (sprintf ("%04d", --$year));
    }
}

# Return an array of lower order datespecs within a given datespec
# of the given type, covering up to today.

sub expand_datespec {
    my($dsp, $dsp_t, $orig, $nd) = @_;
    my($base_tm, $ndays) = &decode_datespec($dsp);
    my(@arr, $m, $y, $w, $tm);
    my($year, $month, $day);
    my($origin_tm, $dummy) = &decode_datespec(&date_to_datespec("%DATASTART%",
								"day"));
    
    if ($base_tm < $orig) {
	$ndays -= ($origin - $base_tm) / $seconds_per_day;
	$base_tm = $orig;
    }
    if ($base_tm < $origin_tm) {
	$ndays -= ($origin_tm - $base_tm) / $seconds_per_day;
	$base_tm = $origin_tm;
    }

    ($year, $month, $day) = unpack("a4a2a2", &tm_to_date($base_tm));

    if ($dsp_t eq "year") {
	($m, $y) = &tm_to_month_and_year(time);
	foreach $i ($year .. $y) {
	    push(@arr, sprintf("%04d", $i));
	}
    } elsif ($dsp_t eq "month") {
	$tm = $base_tm;
	while ($tm < $base_tm + $ndays*$seconds_per_day &&
	       $tm < time)
	{
	    push(@arr, sprintf("%04d-%02d", $year, $month));
	    if (++$month > 12) {
		$month = 1;
		$year++;
	    }
	    ($tm, $dummy) = &decode_datespec(sprintf("%04d-%02d",
						     $year, $month));
	}
    } elsif ($dsp_t eq "week") {
	($week, $year) = &tm_to_week_and_year($base_tm);
	$tm = $base_tm;
	while ($tm < $base_tm + $ndays*$seconds_per_day &&
	       $tm < (time - $seconds_per_day))	# avoid mondays, no data yet
	{
	    push(@arr, sprintf("%04d--%02d", $year, $week));
	    if (++$week > 52) {
		$week = 1;
		$year++;
	    }
	    ($tm, $dummy) = &decode_datespec(sprintf("%04d--%02d",
						     $year, $week));
	}
    } elsif ($dsp_t eq "day") {
	$tm = $base_tm;
	while ($tm < $base_tm + $ndays*$seconds_per_day &&
	       $tm < (time - $seconds_per_day))	# stop on yesterday
	{
	    push(@arr, sprintf("%04d-%02d-%02d",
			       unpack("a4a2a2",
				      &tm_to_date($tm))));
	    $tm += $seconds_per_day;
	}
    } else {
	return undef;
    }
    return @arr;
}


# Return false if a tm is after last midnight
sub tm_in_the_present {
    my($tm) = @_;
    my($start_of_today) = &date_to_tm(&today());
    return (($start_of_today - $tm) >= -7200);
}

sub tm_in_datespec {
    my($tm, $dsp) = @_;
    my($nd, $origin);
    
    ($origin, $nd) = &decode_datespec($dsp);
    if ($dsp eq "epoch") {
	return($tm >= $origin);
    }
    if ($tm >= $origin &&
	$tm <= $origin + ($nd*24*60*60))
    {
	return 1;
    }
    return undef;
}

sub same_day {
    my($tm1, $tm2) = @_;

    return (&tm_to_date($tm1) eq
	    &tm_to_date($tm2));
}

sub same_week {
    my($tm1, $tm2) = @_;

    return (join(':', &tm_to_week_and_year($tm1)) eq
	    join(':', &tm_to_week_and_year($tm2)));
}

sub same_month {
    my($tm1, $tm2) = @_;

    return (join(':', &tm_to_month_and_year($tm1)) eq
	    join(':', &tm_to_month_and_year($tm2)));
}

sub tm_to_datespec {
    my($tm, $dsp_t) = @_;
    my($date);

    if ($dsp_t eq "epoch") { return "epoch"; }
    $date = &tm_to_date($tm);
    return &date_to_datespec($date, $dsp_t);
}

# Translate from "resolution" to actual number of seconds
# remaining until the next such period.  Useful for emitting
# Expiry headers in HTTP.

%res_to_dsp_t = ("raw" => "day",
		 "hr"  => "day",
		 "day" => "day",
		 "week" => "week",
		 "month" => "month");

# Assumption: current time is within $dsp

sub secs_to_expiry {
    my($res) = @_;
    my($now_dsp, $dsp_t);
    my($nx_dsp, $tm, $nd);
    
    if (!defined($dsp_t = $res_to_dsp_t{$res})) {
	return undef;
    }
    $now_dsp = &tm_to_datespec(time, $dsp_t);
    $nx_dsp = &next_datespec($now_dsp);
    ($tm, $nd) = &decode_datespec($nx_dsp);
        
    return ($tm - 2*60*60 - time);
}

1;
