#! %PERL%
#
# $Id$
#
# Copyright (c) 2009,
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

# Input: -t topdir
#	points to top directory.  Uses
#	topdir/conf/polldevs.cf
#	topdir/db/manual-devs
# Output:
#	stderr empty if everyghing ok, otherwise report
#

use strict;
use Getopt::Std;


sub read_config {
    my($f) = @_;
    my($dev, $poll_seen, $def_community);
    our(%polladdr, %device, %community);

    open(IN, $f) || die "Could not open $f: $!\n";
    while(<IN>) {
	chomp;
	if (/^\#/) { next; }
	if (/\s+$/) {
	    printf (STDERR "Extraneous trailing whitespace: %s\n", $_);
	    $_ =~ s/\s+$//;
	}
	if (/^default community:\s(\S+)$/) {
	    $def_community = $1;
	    next;
	}
	if (/^default /) { next; }
	if (! /^name:\s+(\S+)$/) { next; };
	$dev = $1;
	$poll_seen = 0;
	while (!/^$/) {
	    $_ = <IN>;
	    chomp;
	    if (/^address:\s+([0-9].+)$/) {
		$polladdr{$dev} = $1;
		$device{$1} = $dev;
		$poll_seen = 1;
	    }
	    if (/^community:\s+(\S+)$/) {
		$community{$dev} = $1;
	    }
	}
        if (!$poll_seen) {
	    printf (STDERR "Poll address for $dev not found!\n");
	}
	if (!defined($community{$dev})) {
	    $community{$dev} = $def_community;
	}
    }
    close(IN);
}

sub read_manuals {
    my($fn) = @_;
    our(%manual);

    open(IN, $fn) ||
	die "Could not open $fn\n";
    while (<IN>) {
	if (/^;/) { next; }
	chomp;
	$manual{$_} = 1;
    }
    close(IN);
}

sub get_line_names {
    my($dev, $polladdr) = @_;
    my(@a);
    our(%line_name, %seen_name, %max_ix, %seen_at, %community);
    our($es, $opt_v);

    open(IN, "%SNMPNETSTAT% -idnh -t 30 -y $community{$dev} $polladdr 2>&1|");
    while(<IN>) {
	if (/noResponse/) {
	    close(IN);
	    if ($opt_v) {
		printf(STDERR "No response from %s\n", $dev);
	    }
	    return undef;
	}
	if (/^(\d+)\s+\S+\s+\S+ "(.*)"$/) {
	    my($ix) = $1;
	    @a = split(/,[ _]/,$2);
	    if ($#a < 1) { next; }
	    # Trim leading and trailing spaces,
	    my $n = $a[1];
	    $n =~ s/^ +//;
	    $n =~ s/ +$//;
	    # replace remaining spaces with hyphen.
	    # ...so that later use of default "split"
	    # doesn't produce mismatch, new entry and
	    # eventual overflow for the DB(M) entry (!).
	    $n =~ s/ /-/g;
	    my $k = $dev . ":" . $ix;
	    $line_name{$k} = $n;
	    if ($ix > $max_ix{$dev}) {
		$max_ix{$dev} = $ix;
	    }
	    if (defined($seen_at{$n})) {
		printf(STDERR "Duplicate logical port name: %s\n", $n);
		printf(STDERR "Seen both at %s\n", $k);
		printf(STDERR "      and at %s\n", $seen_at{$n});   
		$es++;
	    } else {
		$seen_at{$n} = $k;
	    }
	}
    }
    close(IN);
    return 1;
}

sub usage {
    die "usage: $0 [-v] -t topdir\n";
}

#
# Main
#

our(%polladdr, %manual);
our($opt_t, $opt_v, $es);

&getopts("t:v");

if (!defined($opt_t)) { &usage(); }

&read_config($opt_t . "/conf/polldevs.cf");
&read_manuals($opt_t . "/db/manual-devs");

foreach my $r (keys %polladdr) {
    if (defined($manual{$r})) {
	if ($opt_v) {
	    printf(STDERR "Skiping manual device: %s\n", $r);
	}
	next;
    }
    if ($opt_v) {
	printf(STDERR "Polling %s\n", $r);
    }
    &get_line_names($r, $polladdr{$r});
}
exit($es);
