#!%PERL%
#
# $Id$
#

# Copyright (c) 2003
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

require "getopts.pl";

# push(@INC, "%LIBDIR%");
push(@INC, "%LIBDIR%");

require "date.pl";
require "search.pl";
require "db-lookup.pl";
require "utils.pl";

require "config.pl";

use Data::Dumper;

use strict;


sub save_file {
    my($b) = @_;

    return $DATATREE . "/tail-save/" . $b . ".pl";
}

sub restore_vars {
    my($b) = @_;
    my($p);

    if (!defined($fb->{$b})) {
	my $f = &save_file($b);
	if (open(IN, $f)) {
	    my @lines = <IN>;
	    close(IN);
	    my $var_settings = join("", @lines);
	    eval $var_settings;
	    $fd->{$b} = $p;
	}
    }

    # Set up to read tail of log
    foreach my $v (keys %p->base) {
	$base{$v} = $p->base{$v};
    }
    $date = $p->date;
    $ifspeed = $p->ifspeed;
    $iftype = $p->iftype;
    $ifdescr = $p->ifdescr;
}

sub save_vars {
    my($b) = @_;
    my($p) = { $fd->{$b} };
    
    foreach my $v (keys %base) {
	$p->base{$v} = $base{$v};
    }
    $p->date = $date;
    $p->ifspeed = $ifspeed;
    $p->iftype = $iftype;
    $p->ifdescr = $ifdescr;

    my $f = &save_file($b);
    open(OUT, ">" . $f);
    print OUT Data::Dumper->Dumpx([$p], ["p"]);
    close(OUT);

    undef %count;
    undef %base;
    undef %sample_time;
    undef $date;
    undef $ifspeed;
    undef $iftype;
    undef $ifdescr;
    undef $max_sample;
}

sub process_data {
    my($b) = @_;


}

sub position_file {
    my($fh, $b) = @_;

    my size = stat($fh)[7];
    my pos = $fd->{$b}->{"position"};
    if ($pos > $size) {		# file was (probably) rotated out
	$fd->{$b}->{"position"} = 0;
	return undef;
    }
    return seek($fh, $pos, SEEK_SET);
}

sub save_position {
    my($fh, $b) = @_;

    my $pos = tell($fh);
    $fb->{$b}->{"position"} = $pos;
    $fb->{$b}->{"size"} = stat($fh)[7];
}

sub process_file {
    my($f) = @_;
    my($b) = basename($f);
    my($cat, $base) = &cat_and_base($f, &today());

    if ($cat ne "cat") { return undef; }

    &restore_vars($b);

    open(IN, $f) || { return undef; }
    &position_file(IN, $b);
    &read_log(IN, 1);
    &save_position(IN, $b);
    close(IN);

    &process_data($b);
    &save_vars($b);
    return 1;
}

sub do_all_files {
    my($dir) = &find_data_dir(&today());
    my(@files) = &directory_files($dir);

    foreach $f (@files) {
	&process_file($f);
    }
}

#
# Main
#

&do_all_files();
