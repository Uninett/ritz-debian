#! %PERL%
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
# 3. Neither the name of UNINETT or NORDUnet nor the names
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

use Date::Parse;
use Getopt::Std;
use File::Basename;
use Time::Local;

use strict;

#
# Main
#

our($opt_d, $opt_n, $opt_t, $opt_v);

getopts("d:nt:v");

if (!defined($opt_d) || !defined($opt_t)) {
    &usage();
}
if (! -d $opt_d) {
    if (! mkdir($opt_d)) {
	die "Could not create directory $opt_d: $!";
    }
}
my($ss, $mm, $hh, $d, $m, $y, $z) = strptime($opt_t);
if (!defined($ss)) {
    die "Could not parse date $opt_t";
}
our($time0) = timelocal(0, 0, 0, $d, $m, $y);

if (defined($opt_v)) {
    printf("Time0 = %d\n", $time0);
    printf("which is %d %d %d\n", $d, $m, $y);
}

foreach my $f (@ARGV) {
    if (defined($opt_v)) {
	printf("Processing %s\n", $f);
    }
    if (! &process_file($f)) {
	die "Processing aborted";
    }
}

#
#
#

sub usage {

    printf(STDERR "$0: usage: $0 -d directory -t day-to-split-on files ...\n");
    exit(1);
}

sub process_file {
    my($f) = @_;
    our($opt_d, $opt_n, $time0);
    my(%vals);

    open(O, ">" . $opt_d . "/" . $f) ||
	die "Could not write $opt_d/$f: $!";
    open(I, $f) ||
	die "Could not read $f: $!";
    open(NI, ">" . $f . ".new") ||
	die "Could not write $f.new: $!";
    while(<I>) {
	@_ = split;
	if ($_[0] =~ /^[0-9]+/) {
	    if ($_[0] < $time0) {
		print O $_;
	    } else {
		print NI $_;
	    }
	} else {
	    my($kw) = $_[0];
	    my($val) = join(' ', @_[1..$#_]);
	    if (defined($vals{$kw}) &&
		$vals{$kw} eq $val)
	    {
		next;
	    }
	    $vals{$kw} = $val;
	    print O  $_;
	    print NI $_;
	}
    }
    close(I);
    close(O);
    close(NI);
    if (!defined($opt_n)) {
	rename($f, $f . ".old");
	rename($f . ".new", $f);
    }

    return 1;
}

