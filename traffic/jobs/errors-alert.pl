#!%PERL%

#
# $Id$
#

# Copyright (C) 2021
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

# Flag and re-format interfaces with significant (>6?) error hours
# Defaults to reporting based on previous day's report.

push(@INC, "%LIBDIR%");

use strict;

require 'date.pl';

# Hour threshold for flagging interface
my($ht) = 6;

use Getopt::Std;

our($opt_h);
&getopts("h:");

if (defined($opt_h)) {
    $ht = $opt_h;
}

my $date_str = $ARGV[0];
my $date;

if (!defined($date_str)) {
    $date = &yesterday();
} else {
    $date = &get_date($date_str);
}

sub report_file {
    my($bn, $date) = @_;

    my $tm = &date_to_tm($date);
    my($m, $y);
    ($m, $y) = &tm_to_month_and_year($tm);
    my $md = &tm_to_mday($tm);
    return sprintf("%TOPDIR%/reports/%04d-%02d/%02d/%s", $y, $m, $md, $bn);
}


our(%stats);
our(%names);

my $rep = &report_file("errors.perc", $date);
my $F;
open($F, $rep) || die "Could not open $rep: $!";
while(<$F>) {
    chomp;
    my @a = split;
    my $n = $a[0];
    $names{$n} = 1;
    $stats{$n,"err0"} = $a[1];
    $stats{$n,"err1"} = $a[2];
    $stats{$n,"err2"} = $a[3];
    $stats{$n,"avg-err"} = $a[4];
    $stats{$n,"err3"} = $a[13];
    $stats{$n,"err4"} = $a[14];
}
close($F);

my $anything_p = 0;
foreach my $n (keys %names) {
    foreach my $e ("err0", "err1", "err2", "err3", "err4") {
	if ($stats{$n,$e} > $ht) {
	    $anything_p = 1;
	}
    }
}

if ($anything_p) {
    printf("%-30s  1.0  0.1 1e-2 1e-3 1e-4  24h-avg-inerrors\n");
}


our($S);
open($S, "| sort -n -r +1 +2 +3 +4") || die "Could not start sort";

foreach my $n (keys %names) {
    my $inc = 0;
    foreach my $e ("err0", "err1", "err2", "err3", "err4") {
	if ($stats{$n,$e} > $ht) {
	    $inc = 1;
	}
    }
    if ($inc) {
	printf($S "%-30s ", $n);
	foreach my $e ("err0", "err1", "err2", "err3", "err4") {
	    printf($S "  %2d ", $stats{$n,$e});
	}
	printf($S " %s\n", $stats{$n,"avg-err"});
    }
}
close($S);

if ($anything_p) {
    printf("\n");
    printf("Consult error report on web for further details\n");
}
