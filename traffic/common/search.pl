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
# Routines to look up file/directory names
#

require 'date.pl';

$data_roots = "%DATA_ROOTS%";

foreach $r (split(/ +/, $data_roots)) {
    push(@data_roots, $r);
}

$report_root = "%TOPDIR%/reports";

%catter = (
	   '.gz', "gzcat",
	   '.Z', "zcat",
	   '', "cat"
	   );


# Search for a file with base file name $base
# for the date $date (form yyyymmmdd), return
# pair of "catter" program and fully qualified file name
# or undef if not found

sub find_cat_and_file {
    my($base, $date) = @_;
    my($yyyy, $mm, $dd);

    if ($date !~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	return undef;
    }
    $yyyy = $1;
    $mm = $2;
    $dd = $3;

    foreach $d (@data_roots) {
	foreach $suf (keys %catter) {
	    $f = sprintf("%s/%04d-%02d/%02d/%s%s",
			 $d, $yyyy, $mm, $dd, $base, $suf);
	    if (-f $f) {
		return ($catter{$suf}, $f);
	    }
	}
    }
    if ($date eq &today()) {
	$f = sprintf("%s/data/today/%s", "%TOPDIR%", $base);
	if (-f $f) {
	    return ("cat", $f);
	}
    }
    return undef;
}

# Find data directory for a given date (form yyyymmdd)

sub find_data_dir {
    my($date) = @_;
    my($yyyy, $mm, $dd);
    my($dn);

    if ($date !~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	return undef;
    }
    $yyyy = $1;
    $mm = $2;
    $dd = $3;

    foreach $d (@data_roots) {
	$dn = sprintf("%s/%04d-%02d/%02d", $d, $yyyy, $mm, $dd);
	if ( -d $dn ) {
	    return $dn;
	}
    }
    if ($date eq &today()) {
	return "%TOPDIR%/data/today";
    }
    return undef;
}

# Return (possibly newly created) report directory name for 
# a given date (form yyyymmdd).

sub report_dir_create {
    my($date) = @_;
    my($yyyy, $mm, $dd);
    my($dn);

    if ($date !~ /(\d\d\d\d)(\d\d)(\d\d)/) {
	return undef;
    }
    $yyyy = $1;
    $mm = $2;
    $dd = $3;

    $dn = sprintf("%s/%04d-%02d", $report_root, $yyyy, $mm);
    if (! -d $dn) {
	mkdir ($dn, 0777);
    }
    $dn = sprintf("%s/%04d-%02d/%02d", $report_root, $yyyy, $mm, $dd);
    if (! -d $dn) {
	mkdir ($dn, 0777);
    }
    return $dn;
}

# Return (possibly newly created) report directory name for
# a given week in a given year

sub week_report_dir_create {
    my($week, $year) = @_;
    my($dn);

    $dn = sprintf("%s/weekly/%04d", $report_root, $year);
    if (! -d $dn) {
	mkdir ($dn, 0777);
    }
    $dn = sprintf("%s/weekly/%04d/%02d", $report_root, $year, $week);
    if (! -d $dn) {
	mkdir ($dn, 0777);
    }
    return $dn;
}

# Return the path name for the month given

sub month_report_dir {
    my($datespec) = @_;
    my($month, $year, $tm, $x);

    ($tm, $x) = &decode_datespec($datespec);
    ($month, $year) = &tm_to_month_and_year($tm);
    
    return sprintf("%s/monthly/%04d/%02d", $report_root, $year, $month);
}
# Return (possibly newly created) report directory for
# a given month in a given year

sub month_report_dir_create {
    my($datespec) = @_;
    my($month, $year, $tm, $x);
    my($dn);

    ($tm, $x) = &decode_datespec($datespec);
    ($month, $year) = &tm_to_month_and_year($tm);

    # Should instead have "mkdir -p" equivalent which did this for us
    $dn = sprintf("%s/monthly/%04d", $report_root, $year);
    if (! -d $dn) {
	mkdir ($dn, 0777);
    }
    $dn = sprintf("%s/monthly/%04d/%02d", $report_root, $year, $month);
    if (! -d $dn) {
	mkdir ($dn, 0777);
    }
    return $dn;
}


# Find existing daily report directory for the given day
# or undef if not found.

sub find_day_report_dir {
    my($dsp) = @_;
    my($yyyy, $mm, $dd, $dn);
    my($dn);

    if ($dsp !~ /(\d\d\d\d)-(\d\d)--(\d\d)/ &&
	$dsp !~ /(\d\d\d\d)-(\d\d)-(\d\d)/)
    {
	return undef;
    }
    $yyyy = $1;
    $mm = $2;
    $dd = $3;

    $dn = sprintf("%s/%04d-%02d/%02d", $report_root, $yyyy, $mm, $dd);
    if (! -d $dn) {
	return undef;
    }
    return $dn;
}
    
# Find weekly report dir for the given week
# or undef if not found.

sub find_week_report_dir {
    my($dsp) = @_;
    my($dn, $year, $week);

    if ($dsp !~ /(\d\d\d\d)--(\d\d?)/) {
	return undef;
    }
    $year = $1;
    $week = $2;
    $dn = sprintf("%s/weekly/%04d/%02d", $report_root, $year, $week);
    if (! -d $dn) {
	return undef;
    }
    return $dn;
}

# Find monthly report dir for given month
# or undef if not found

sub find_month_report_dir {
    my($dsp) = @_;
    my($dn, $year, $mm);

    if ($dsp !~ /(\d\d\d\d)-(\d\d?)/) {
	return undef;
    }
    $year = $1;
    $mm = $2;
    
    $dn = sprintf("%s/monthly/%04d/%02d", $report_root, $year, $mm);
    if (! -d $dn) {
	return undef;
    }
    return $dn;
}

1;
