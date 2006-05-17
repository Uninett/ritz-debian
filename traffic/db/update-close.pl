#! %PERL%
#
# $Id$
#

# Copyright (c) 2006
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
# usage: update-close [-v] [-n] -t topdir -d yyyymmdd
#
# Inspects the entries in topdir/db/ntf & topdir/db/ftn
# closed on the given date and tries to backdate the close
# time to the last occurrance of the listed interface log file.
#
# Typically used right after the date when the "close entries"
# code in update-dbs.pl has been deployed.
#

require 'getopts.pl';

require 'date.pl';
require 'search.pl';


sub open_dbs {
    my($dbdir) = @_;

    dbmopen(%ftn, "$dbdir/ftn", 0664);
    dbmopen(%ntf, "$dbdir/ntf", 0664);
}

sub close_dbs {

    dbmclose(%ftn);
    dbmclose(%ntf);
}

sub closed_entry {
    my($e) = @_;

    if ($e =~ /-$/) {
	return undef;
    }
    return 1;
}

sub find_close_date {
    my($fn) = @_;

    my($date) = $opt_d;
    my($tm) = &date_to_tm($date);
    my($prevdate) = $date;

    while(&find_data_dir($date)) {
	my($c, $f) = &find_cat_and_file($fn, $date);
	if (defined($f)) {
	    return $prevdate;
	}
	$prevdate = $date;
	$tm -= 3600 * 24;
	$date = &tm_to_date($tm);
    }
}

sub update_dbs {

    foreach my $ln (keys %ntf) {
	my($s) = $ntf{$ln};
	if (!closed_entry($s)) { next; }
	my(@a) = split(/:/, $s);
	my(@b) = split(/ /, $a[$#a]);
	my($fn) = $b[0];
	my(@c) = split(/-/, $b[1]);
	my($cdate) = $c[1];
	if ($cdate != $opt_d) { next; }
	my($newcdate) = &find_close_date($fn);
	if (!defined($newcdate)) { next; }
	my($new_entry) = substr($s, 0, -6) . $newcdate;
	if (!defined($opt_n)) {
	    $ntf{$ln} = $new_entry;
	}
	if (defined($opt_v)) {
	    printf(STDERR "Changed close date %s to %s for %s / %s\n",
		   $cdate, $newcdate, $ln, $fn);
	}
    }
    foreach my $fn (keys %ftn) {
	my($s) = $ftn{$fn};
	if (!closed_entry($s)) { next; }
	my(@a) = split(/:/, $s);
	my(@b) = split(/ /, $a[$#a]);
	my($ln) = $b[0];
	my(@c) = split(/-/, $b[1]);
	my($cdate) = $c[1];
	if ($cdate != $opt_d) { next; }
	my($newcdate) = &find_close_date($fn);
	if (!defined($newcdate)) { next; }
	my($new_entry) = substr($s, 0, -6) . $newcdate;
	if (!defined($opt_n)) {
	    $ftn{$fn} = $new_entry;
	}
	if (defined($opt_v)) {
	    printf(STDERR "Changed close date %s to %s for %s / %s\n",
		   $cdate, $newcdate, $fn, $ln);
	}
    }
}

sub usage {

    die "usage: $0 [-v] [-n] -t topdir -d yyyymmdd\n";
}


&Getopts("d:nt:v");

if (!defined($opt_t)) { &usage(); }
if (!defined($opt_d)) { &usage(); }
if ($opt_d !~ /^\d\d\d\d\d\d\d\d$/) { &usage(); }

if (defined($opt_v)) {
    select(STDERR);
    $| = 1;
    select(STDOUT);
}
&open_dbs();
&update_dbs();
reset;
&close_dbs();
