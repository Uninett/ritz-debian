#!%PERL%
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
# Script to extract certain coloumns from a report.
#

require 'getopts.pl';

push(@INC, "%LIBDIR%");

require 'date.pl';
require 'search.pl';


%find_dir = ("day"	=> \&find_day_report_dir,
	     "week"	=> \&find_week_report_dir,
	     "month"	=> \&find_month_report_dir,
	     );

%cols = (
	 "day" => {
	     "traffic" => {
		 "peak" =>	[5, 7, 11],
		 "busy" =>	[1, 3, 11],
		 "avg"  =>	[9, 10, 11],
	     },
	     # XXX add other types later
	 },
	 "week" => {
	     "traffic" => {
		 "peak" =>	[3, 4, 11],
		 "busy" =>	[5, 7, 11],
		 "avg"  =>	[9, 10, 11],
	     },
	 },
	 "month" => {
	     "traffic" => {
		 "peak" =>	[1, 2, 9],
		 "busy" =>	[3, 5, 9],
		 "avg"  =>	[7, 8, 9],
	     },
	 },
	 );

%file = (
	 "traffic" => "traffic",
	 # XXX later add discards -> errors.perc etc.
	 );


sub select_and_print {
    my($dsp, $type, $select) = @_;
    my($dir_finder);
    my($dt, $d, $f, @f, @s, $speed);
    my($inc, $outc, $sc);

    $dt = &datespec_type($dsp);
    if (!defined ($dir_finder = $find_dir{$dt})) {
	return undef;
    }
    $d = &$dir_finder($dsp);
    $f = $d . "/" . $file{$type};
    if (! -f $f) {
	&err("Cannot find file $f");
	return undef;
    }
    if (! open(IN, $f)) {
	&err("Could not open $f: $!");
	return undef;
    }

    ($inc, $outc, $sc) = @{ $cols{$dt}{$type}{$select} };

    while(<IN>) {
	chop;
	@f = split;
	@s = split(/\//, $f[$sc]);
	$speed = $s[$#s];
	printf("%s %s %s %s\n", $f[0], $f[$inc], $f[$outc], $speed);
    }
    close(IN);
}

sub err {
    my($msg) = @_;

    printf(STDERR "%s\n", $msg);
}


#
# Main
#

&Getopts("d:t:s:");

if (!defined($opt_d)) {
    $opt_d = &yesterday_spec();
}

if (!defined($opt_t)) {
    $opt_t = "traffic";
}

if (!defined($opt_s)) {
    $opt_s = "peak";
}

&select_and_print($opt_d, $opt_t, $opt_s);
