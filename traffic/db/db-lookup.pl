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


# Look up linename -> base file name
# or base file name -> line name
# in database for a given date (form yyyymmdd)

package db_lookup;

use strict;
use BerkeleyDB;

our($ROOT) = "%TOPDIR%";
our($FTN_DB) = "$ROOT/db/ftn";
our($NTF_DB) = "$ROOT/db/ntf";


# Auto-detect if the administrator has taken the leap and converted
# to using BerkeleyDB when opening the hashed files

sub open_db {
    my($db, $rh) = @_;
    my($dbf) = $db . ".bdb";

    if (-f $dbf) {		# has converted to Berkeley DB
	tie(%{ $rh }, 
		'BerkeleyDB::Hash', 
			-Filename => $dbf,
			-Flags => DB_RDONLY
	    )
	    or die "Cannot open $dbf: $! $BerkeleyDB::Error\n";
    } else {
	dbmopen(%{ $rh }, $db, 0666);
    }
}


# Extract data value corresponding to the given date
# from the given DB entry

sub find_entry {
    my($entry, $date) = @_;
    my(@a, @b, @c, $i);
    
    @a = split(/:/,$entry);	# :-separated separate entries
    for ($i = $#a; $i >= 0; $i--) {
	@b = split(/ /, $a[$i]); # "value date-date" or "value date-"
	@c = split(/-/, $b[1]);	# dates
	if ($#c == 0) {
	    if ($date >= $c[0]) {
		return $b[0];
	    }
	} else {
	    if ($date >= $c[0] && $date <= $c[1]) {
		return $b[0];
	    }
	}
    }
    return undef;
}

# Line name -> base of file name

sub main::name_to_file {
    my($name, $date) = @_;
    my($entry, $base, $f);
    our($ntf_open, %ntf_db, $NTF_DB);

    if ($date !~ /\d\d\d\d\d\d\d\d/) {
	return undef;
    }

    if (!$ntf_open) {
	open_db($NTF_DB, \%ntf_db);
	$ntf_open = 1;
    }
    if (! defined($entry = $ntf_db{$name})) {
	return undef;
    }
    return &find_entry($entry, $date);
}

# base of file name -> line name

sub main::file_to_name {
    my($file, $date) = @_;
    my($entry, $val);
    our($ftn_open, %ftn_db, $FTN_DB);

    if ($date !~ /\d\d\d\d\d\d\d\d/) {
	return undef;
    }

    if (!$ftn_open) {
	open_db($FTN_DB, \%ftn_db);
	$ftn_open = 1;
    }
    if (! defined($entry = $ftn_db{$file})) {
	return undef;
    }
    return &find_entry($entry, $date);
}

# Find data origin date for a logical port name

sub main::data_origin {
    my($port) = @_;
    my($entry, @a, @b, @c);
    our($ntf_open, %ntf_db, $NTF_DB);

    if (!$ntf_open) {
	open_db($NTF_DB, \%ntf_db);
	$ntf_open = 1;
    }

    if (!defined($entry = $ntf_db{$port})) {
	return undef;
    }
    @a = split(/:/, $entry);	# "value date-date:value date-date..."
    @b = split(/ /, $a[0]);	# "value date-date" or "value date-"
    @c = split(/-/, $b[1]);	# get the date(s)
    return $c[0];
}

sub main::all_port_names {
    my($date) = @_;
    my($k, $val, @l);
    our($ntf_open, %ntf_db, $NTF_DB);

    if (!$ntf_open) {
	open_db($NTF_DB, \%ntf_db);
	$ntf_open = 1;
    }
    while(($k, $val) = each %ntf_db) {
	if (&find_entry($val, $date)) {
	    push(@l, $k);
	}
    }
    return @l;
}

1;
