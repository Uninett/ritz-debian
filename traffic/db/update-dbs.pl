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

# Input: ifs.cf on standard input or on command line
#	 ../db/manual-rtrs for list of routers where mapping is
#		manually maintained
# Output: updated ntf and ftn DBM databases.
#
# Check config database for possible updates, do updates
# if required.
#
# TODO:
#   Assumes "public" is a usable community string.

# Relies on certain conventions for "interface description" field
# on Cisco routers; briefly "bla bla, logical-port-name, bla bla"
# where the ", " is the field delimiter.

sub open_dbs {

    dbmopen(%ftn, "%TOPDIR%/db/ftn", 0664);
    dbmopen(%ntf, "%TOPDIR%/db/ntf", 0664);
}

sub close_dbs {

    dbmclose(%ftn);
    dbmclose(%ntf);
}

sub read_config {
    local($rtr_name);
    local($poll_seen);

    while(<>) {
	if (! /router\s+(\S+)/) { next; };
	$rtr_name = $1;
	$poll_seen = 0;
	while (!$poll_seen && !/}/) {
	    $_ = <>;
	    if (/polladdr\s+([0-9].+);/) {
		$polladdr{$rtr_name} = $1;
		$poll_seen = 1;
	    }
	}
        if (!$poll_seen) {
	    printf (STDERR "Poll address for $rtr_name not found!\n");
	}
    }
}

sub read_manuals {
    local($fh) = @_;

    while (<$fh>) {
	if (/^;/) { next; }
	chop;
	$manual{$_} = 1;
    }
}

sub alive {
    local($address) = @_;

    # XXX Name of command should go in a config file
    open(IN, "%PING% -s 56 -c 5 -i 2 $address 2>&1 |");
    while(<IN>) {
	if (! /packet loss/) { next; }
	if (/100% packet loss/) { close(IN); return undef; }
    }
    close(IN);
    return 1;
}

sub get_addrs {
    local($router, $polladdr) = @_;

    if ($dead{$polladdr} || ! &alive($polladdr)) {
	$dead{$polladdr} = 1;
	return undef;
    }
    # XXX Name of command should go in a config file
    open(IN, "%SNMPNETSTAT% $polladdr -inh 2>&1|");
    while(<IN>) {
	if (/SNMP timeout/) { close(IN); return undef; }
	chop;
	@_ = split;
	$as{$router . ":" . $_[0]} = $_[2];
	$address{$router . ":" . $_[0]} = $_[4];
	if (!defined($max_ix{$router}) || $_[0] > $max_ix{$router}) {
	    $max_ix{$router} = $_[0];
	}
    }
    close(IN);
    return 1;
}

sub get_line_names {
    local($router, $polladdr) = @_;
    local(@a);

    if ($dead{$polladdr} || ! &alive($polladdr)) {
	$dead{$polladdr} = 1;
	return undef;
    }
    open(IN, "%SNMPNETSTAT% $polladdr -idnh 2>&1|");
    while(<IN>) {
	if (/SNMP timeout/) { close(IN); return undef; }
	if (/^(\d+)\s+\S+\s+\d+ "(.*)"$/) {
	    @a = split(/, /,$2);
	    if ($#a < 1) { next; }
	    $line_name{$router . ":" . $1} = $a[1];
	    if ($1 > $max_ix{$router}) {
		$max_ix{$router} = $1;
	    }
	}
    }
    close(IN);
    return 1;
}

sub get_current_state {
    local($k);
    local($fn);

    foreach $r (keys %polladdr) {
	if (defined($manual{$r})) { next; }
	&get_addrs ($r, $polladdr{$r});
	&get_line_names ($r, $polladdr{$r});

	for $i (1 .. $max_ix{$r}) {
	    $k = $r . ":" . $i;
	    if (!defined($address{$k})) { next; } # skip holes in ifIndex space
	    if ($as{$k} eq "off") { next; } # skip administratively down ifs.
	    if (!defined($line_name{$k})) { next; } # skip "unnamed" lines

	    if ($address{$k} eq "none") {
		$address{$k} = "#" . $i;
	    }
	    $fn = $r . "." . $address{$k};
	    $file{$line_name{$k}} = $fn;
	    $line{$fn} = $line_name{$k};
	}
    }
}

sub update_dbs {
    local($now);
    local(@a,@b);
    
    $now = &get_today_str();
    foreach $ln (keys %file) {
	if (!defined $file{$ln}) { next; }
	if (defined $ntf{$ln}) {
	    @a = split(/:/, $ntf{$ln});
	    @b = split(/ /, $a[$#a]);
	    if ($b[0] eq $file{$ln}) {
		next;
	    }
	    $ntf{$ln} .= $now . ":" . $file{$ln} . " " . $now . "-";
	} else {
	    $ntf{$ln} = $file{$ln} . " " . $now . "-";
	}
    }
    foreach $fn (keys %line) {
	if (!defined $line{$fn}) { next; }
	if (defined $ftn{$fn}) {
	    @a = split(/:/, $ftn{$fn});
	    @b = split(/ /, $a[$#a]);
	    if ($b[0] eq $line{$fn}) {
		next;
	    }
	    $ftn{$fn} .= $now . ":" . $line{$fn} . " " . $now . "-";
	} else {
	    $ftn{$fn} = $line{$fn} . " " . $now . "-";
	}
    }
}

sub get_today_str {
    local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
    local($today_str);
    
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
    
    $today_str = sprintf("%04d%02d%02d", $year+1900, $mon+1, $mday);
}


# Main (test)

&open_dbs ();
&read_config ();

open(IN, "%TOPDIR%/db/manual-rtrs") ||
    die "Could not open %TOPDIR%/db/manual-rtrs\n";
&read_manuals(IN);
close(IN);

&get_current_state ();
&update_dbs ();
reset;
&close_dbs ();
