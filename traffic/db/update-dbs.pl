#! %PERL%
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

# Input: -t topdir
#	points to top directory.  Implicitly uses
#	topdir/conf/polldevs.cf,
#	topdir/db/ntf, topdir/db/ftn hashed files and
#	topdir/db/manual-devs for list of devices where mapping is
#	manually maintained
# Output: updated ntf and ftn hashed files
#
# Check config database for possible updates, do updates
# if required.
#
# Relies on certain conventions for "interface description" field
# on Cisco devices; briefly "bla bla, logical-port-name, bla bla"
# where the ", " is the field delimiter (note: two chars!).

require 'getopts.pl';

sub open_dbs {
    my($dbdir) = @_;

    dbmopen(%ftn, "$dbdir/ftn", 0664);
    dbmopen(%ntf, "$dbdir/ntf", 0664);
}

sub close_dbs {

    dbmclose(%ftn);
    dbmclose(%ntf);
}

sub read_config {
    my($f) = @_;
    my($dev, $poll_seen, $def_community);

    open(IN, $f) || die "Could not open $f: $!\n";
    while(<IN>) {
	chomp;
	if (/^\#/) { next; }
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
    my($fh) = @_;

    while (<$fh>) {
	if (/^;/) { next; }
	chop;
	$manual{$_} = 1;
    }
}

sub alive {
    my($address) = @_;

    if (defined($opt_n)) { return 1; }
    # XXX Name of command should go in a config file
    open(IN, "%PING% -s 56 -c 5 -i 2 $address 2>&1 |");
    while(<IN>) {
	if (! /packet loss/) { next; }
	if (/100% packet loss/) {
	    printf(STDERR "No ping response from %s\n", $device{$address});
	    close(IN); return undef;
	}
    }
    close(IN);
    return 1;
}

sub get_addrs {
    my($dev, $polladdr) = @_;

    if ($dead{$polladdr} || ! &alive($polladdr)) {
	$dead{$polladdr} = 1;
	return undef;
    }
    # XXX Name of command should go in a config file
    open(IN, "%SNMPNETSTAT% -inh -y $community{$dev} $polladdr 2>&1|");
    while(<IN>) {
	if (/noResponse/) {
	    printf(STDERR "noResponse from %s\n", $dev);
	    close(IN);
	    $dead{$polladdr} = 1;
	    return undef;
	}
	chop;
	@_ = split;
	$as{$dev . ":" . $_[0]} = $_[2];
	$address{$dev . ":" . $_[0]} = $_[4];
	if (!defined($max_ix{$dev}) || $_[0] > $max_ix{$dev}) {
	    $max_ix{$dev} = $_[0];
	}
    }
    close(IN);
    return 1;
}

sub get_line_names {
    my($dev, $polladdr) = @_;
    my(@a);

    if ($dead{$polladdr} || ! &alive($polladdr)) {
	$dead{$polladdr} = 1;
	return undef;
    }
    open(IN, "%SNMPNETSTAT% -idnh -y $community{$dev} $polladdr 2>&1|");
    while(<IN>) {
	if (/noResponse/) {
	    printf(STDERR "noResponse from %s\n", $dev);
	    close(IN);
	    $dead{$polladdr} = 1;
	    return undef;
	}
	if (/^(\d+)\s+\S+\s+\S+ "(.*)"$/) {
	    @a = split(/, /,$2);
	    if ($#a < 1) { next; }
	    # Trim leading and trailing spaces,
	    $a[1] =~ s/^ +//;
	    $a[1] =~ s/ +$//;
	    # replace remaining spaces with hyphen.
	    # ...so that later use of default "split"
	    # doesn't produce mismatch, new entry and
	    # eventual overflow for the DB(M) entry (!).
	    $a[1] =~ s/ /-/g;
	    $line_name{$dev . ":" . $1} = $a[1];
	    if ($1 > $max_ix{$dev}) {
		$max_ix{$dev} = $1;
	    }
	}
    }
    close(IN);
    return 1;
}

sub get_current_state {
    my($k);
    my($fn);

    if (defined($opt_d)) {
	printf(STDERR "Getting current state\n");
    }
    foreach $r (keys %polladdr) {
	if (defined($manual{$r})) {
	    if (defined($opt_d)) {
		printf(STDERR "Router %s - manual mapping\n", $r);
	    }
	    next;
	}
	if (defined($opt_d)) {
	    printf(STDERR "Checking %s for addresses...", $r);
	}
	&get_addrs ($r, $polladdr{$r});
	if (defined($opt_d)) {
	    printf(STDERR "interface descs...");
	}
	&get_line_names ($r, $polladdr{$r});
	if (defined($opt_d)) {
	    printf(STDERR "\n");
	}

	for $i (1 .. $max_ix{$r}) {
	    $k = $r . ":" . $i;
	    if (!defined($address{$k})) { next; } # skip holes in ifIndex space
	    if ($as{$k} eq "off") { next; } # skip administratively down ifs.
	    if (!defined($line_name{$k})) { next; } # skip "unnamed" lines

	    if ($address{$k} eq "none") {
		$address{$k} = "#" . $i;
	    }
	    $fn = $r . "." . $address{$k};
	    # Check if we should override existing mapping
	    if (defined($file{$line_name{$k}})) {
		# Only override if previous value didn't have an address
		# ...and current one has
		if ($file{$line_name{$k}} =~ /\#/ && $fn !~ /\#/) {
		    $file{$line_name{$k}} = $fn;
		}
	    } else {
		$file{$line_name{$k}} = $fn;
	    }
	    $line{$fn} = $line_name{$k};
	}
    }
}

sub update_dbs {
    my($now);
    my(@a,@b);
    
    $now = &get_today_str();

    if (defined($opt_d)) {
	printf(STDERR "Checking name -> file DB\n");
    }
    foreach $ln (keys %file) {
	if (!defined $file{$ln}) { next; }
	if (defined($opt_d)) {
	    printf(STDERR "Checking %s ...", $ln);
	}
	if (defined $ntf{$ln}) {
	    # separate entries in name-to-file database
	    @a = split(/:/, $ntf{$ln});
	    # split last entry on spaces
	    @b = split(/ /, $a[$#a]);
	    if ($b[0] eq $file{$ln}) {
		if (defined($opt_d)) {
		    printf(STDERR "...same\n");
		}
		# same as before
		next;
	    }
	    # Tack on new entry at the end
	    $ntf{$ln} .= $now . ":" . $file{$ln} . " " . $now . "-";
	    if (defined($opt_v)) {
		printf(STDERR "\n");
	    }
	    if (defined($opt_v) || defined($opt_d)) {
		printf(STDERR "Updated entry: %s -> %s\n",
		       $ln, $file{$ln});
	    }
	} else {
	    # Add completely new entry
	    $ntf{$ln} = $file{$ln} . " " . $now . "-";
	    if (defined($opt_v)) {
		printf(STDERR "\n");
	    }
	    if (defined($opt_v) || defined($opt_d)) {
		printf(STDERR "Added new entry: %s -> %s\n",
		       $ln, $file{$ln});
	    }
	}
    }
    if (defined($opt_d)) {
	printf(STDERR "Checking file -> name DB\n");
    }
    foreach $fn (keys %line) {
	if (!defined $line{$fn}) { next; }
	if (defined($opt_d)) {
	    printf(STDERR "Checking %s ...", $fn);
	}
	if (defined $ftn{$fn}) {
	    # separate entries in file-to-name database
	    @a = split(/:/, $ftn{$fn});
	    # split last entry on spaces
	    @b = split(/ /, $a[$#a]);
	    if ($b[0] eq $line{$fn}) {
		if (defined($opt_d)) {
		    printf(STDERR "...same\n");
		}
		# same as before
		next;
	    }
	    # Tack on new entry at the end
	    $ftn{$fn} .= $now . ":" . $line{$fn} . " " . $now . "-";
	    if (defined($opt_v)) {
		printf(STDERR "\n");
	    }
	    if (defined($opt_v) || defined($opt_d)) {
		printf(STDERR "Updated entry: %s -> %s\n",
		       $fn, $line{$fn});
	    }
	} else {
	    # Add completely new entry
	    $ftn{$fn} = $line{$fn} . " " . $now . "-";
	    if (defined($opt_v)) {
		printf(STDERR "\n");
	    }
	    if (defined($opt_v) || defined($opt_d)) {
		printf(STDERR "\nAdded new entry: %s -> %s\n",
		       $fn, $line{$fn});
	    }
	}
    }
}

sub get_today_str {
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
    my($today_str);
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
    
    $today_str = sprintf("%04d%02d%02d", $year+1900, $mon+1, $mday);
}

sub usage {
    die "usage: $0 -t topdir\n";
}


# Main (test)

&Getopts("dnt:v");

if (!defined($opt_t)) { &usage(); }
if (defined($opt_v) || defined($opt_d)) {
    select(STDERR);
    $| = 1;
    select(STDOUT);
}

&open_dbs($opt_t . "/db");
&read_config($opt_t . "/conf/polldevs.cf");

open(IN, "$opt_t/db/manual-devs") ||
    die "Could not open $opt_t/db/manual-devs\n";
&read_manuals(IN);
close(IN);

&get_current_state();
&update_dbs();
reset;
&close_dbs();
