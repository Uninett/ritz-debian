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
# A set of plotting routines.  Provides a set of plotting functions
# which gives a layer of abstraction under which several different
# plotting packages can be hidden (gnuplot and xmgr comes to mind)
# Currently only implements gnuplot, and the abstraction is not
# "complete" in any sense.
#

#package gnuplot;

$plt_docbase = "%TOPDIR%/data/plot";

%device_init_strings =
    (
     'postscript', 'color "Helvetica-Bold" 16',
     'x11', '',
     'ppm', '',
     'fig', '',
     'png', 'small',
    );

%device_exit_strings =
    (
     'postscript', '',
     'x11', 'pause 30 "Sleeping for 30 secs ..."',
     'ppm', '',
     'fig', '',
     'png', '',
    );

# Given a plot type, line name, datespec and device
# return the filenames (relative to $plt_docbase, and absolute) of a plotfile
sub plot_names {
    my($plot, $line, $date, $device) = @_;
    my($file1, $file2, $file3);

    $file1 = sprintf("%s.%s.%s.%s.plt", $plot, $line, $date, $device);
    $file2 = sprintf("%s.%s.%s.data", $plot, $line, $date);
    $file3 = sprintf("%s.%s.%s.plt", $plot, $line, $date);
    return(
	   # Gnuplot command file, relative
	   sprintf("/plt-cache/%s", $file1),
	   # Gnuplot top-level command file, absolute
	   sprintf("%s/plt-cache/%s", $plt_docbase, $file1),
	   # Actual X-Y plot data, absolute
	   sprintf("%s/plt-cache/%s", $plt_docbase, $file2),
	   # Dev-independent gnuplot command file
	   sprintf("%s/plt-cache/%s", $plt_docbase, $file3),
	   );
}

sub plot_init {
    my($device) = @_;
    if (defined($device_init_strings{$device})) {
	return("set output\nset term $device " . 
		$device_init_strings{$device} . "\n");
    } else {
	return undef;
    }
}

sub plot_exit {
    my($device) = @_;
    if (defined($device_exit_strings{$device})) {
	return($device_exit_strings{$device} . "\n");
    } else {
	return undef;
    }
}
sub plot_err {
    my($errstring) = @_;
    printf(STDERR "$errstring");
}

sub plot_title {
    my($title) = @_;
    return "set title \"$title\"\n";
}

sub plot_xlabel {
    my($xlabel) = @_;
    return "set xlabel \"$xlabel\" offset 0,-0.6\n";
}
sub plot_ylabel {
    my($ylabel) = @_;
    return "set ylabel \"$ylabel\"\n";
}
sub plot_yrange {
    my($yrange) = @_;
    return "set yrange [$yrange]\n";
}

# plot_set_xtics assumes that the unit used on the
# X axis is hours.

sub plot_set_xtics {
    my($base_tm, $no_days, $period_days) = @_;
    my($xtics, $tm, $d, $date, $s);
    my($lastweek, $lastmonth, $month, $year, $week);
    my($tm) = $base_tm;

    return undef if ($no_days == 1);

    $xtics = "set xtics (";
    if ($no_days > 1 && $no_days <= 8) {
	foreach $d (0 .. $period_days - 1) {
	    $tic = sprintf(" %3d", $d*24);
	    $tm = $base_tm + ($d) * (60*60*24);
	    $xtics .= "\"". &tm_to_day_of_week($tm) . "\"$tic,";
	}
    } elsif ($no_days <= 31) {
	foreach $d (0 .. $period_days - 1) {
	    $tic = sprintf(" %3d", $d*24);
	    $tm = $base_tm + $d * (60*60*24);
	    if ($d % 2 == 0) {
		$xtics .= "\"" . &tm_to_mday($tm) . "\"$tic,";
	    }
	}
    } elsif ($no_days > 365) {
	foreach $d (0 .. $period_days - 1) {
	    $tic = sprintf(" %3d", $d*24);
	    $tm = $base_tm + $d * (60*60*24);
	    $date = &tm_to_date($tm);
	    # 1st Jan, Apr, Jul and Oct
	    if ($date =~ /(\d\d\d\d)(0[147]|10)01/) {
		$s = &pretty_date($date);
		@_ = split(/ /, $s);
		$xtics .= "\"1" . $_[2] . "\\n" . $1 . "\"$tic,";
	    }
	}
    } elsif ($no_days > 100) {	# approximately 14 weeks, use month as tickmark
	foreach $d (0 .. $period_days - 1) {
	    $tic = sprintf(" %3d", $d*24);
	    $tm = $base_tm + $d * (60*60*24);
	    ($month, $year) = &tm_to_month_and_year($tm);
	    if (!defined($lastmonth)) {
		$lastmonth = $month;
	    }
	    if ($month != $lastmonth) {
		$lastmonth = $month;
		$date = &tm_to_date($tm);
		$s = &pretty_date($date);
		@_ = split(/ /, $s);
		$xtics .= "\"1 " . $_[2] . "\\n" . $_[3] . "\"$tic,";
	    }
	}
    } else {			# We use weeknos as tic marks
	foreach $d (0 .. $period_days - 1) {
	    $tic = sprintf(" %3d", $d*24);
	    $tm = $base_tm + $d * (60*60*24);
	    ($week, $year) = &tm_to_week_and_year($tm);
	    if ((!defined($lastweek) ||
		 $week ne $lastweek))
	    {
		$lastweek = $week;
		$xtics .= "\"week $week\\n$year\" $tic,";
	    }
	}
    }
    chop $xtics;
    $xtics .= ")\n";
    return ($xtics);
}

#sub plot_xy_data_files {
#    local (*dataset) = @_;
#    return "plot \"$file\" title \"$title\" with lines,";
#}

1;
