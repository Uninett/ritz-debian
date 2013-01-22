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
# Run this right before midnight to save the previous day's logs
#

push(@INC, "%TOPDIR%/conf");

require 'zino-config.pl';

sub get_date_strings {
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
    our($ym_str, $day_str, $yyyymmdd);

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($^T);		# script start time
    
    $ym_str = sprintf("%4d-%02d", $year+1900, $mon+1);
    $day_str = sprintf("%02d", $mday);
    $yyyymmdd = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
}

sub save_files {
    our($ym_str, $day_str, $yyyymmdd);
    my($top, $savedir, $today, $cmd);
    my($mdir, $cmd, $ret);

    $top = $DATATREE;
    $mdir = $top . "/" . $ym_str;
    $savedir = $mdir . "/" . $day_str;
    $backupdir = $top . "/backup/" . $day_str;
    $today = $top . "/today";

    if ( ! -d $mdir ) {
	if (mkdir ($mdir, 0755) != 1) {
	    die "Could not create $mdir: $!\n";
	}
    }
    if ( ! -d $savedir ) {
	if (mkdir ($savedir, 0755) != 1) {
	    die "Could not create $savedir: $!\n";
	}
    }
    if (! -d $backupdir) {
	if (mkdir ($backupdir, 0755) != 1) {
	    die "Could not create $backupdir: $!\n";
	}
    }

    $cmd = "find $today -type f | xargs %TOPDIR%/bin/move-to $savedir";
    $ret = system($cmd) / 256;
    if ($ret != 0) {
	die "Could not move files\n";
    }
    
    $cmd = "find $savedir -type f | xargs %TOPDIR%/bin/copy-to $backupdir";
    $ret = system($cmd) / 256;
    if ($ret != 0) {
	die "Could not save files in backup directory\n";
    }

    # Clean up any gzipped files from last month
    $cmd = "find $backupdir -name '*.gz' -type f | xargs rm -f";
    # ignore any error code returned
    system($cmd);

    $cmd = "find $backupdir -type f | xargs $gzip";
    $ret = system($cmd) / 256;
    if ($ret != 0) {
	die "Could not compress backup files\n";
    }
}

sub do_report {
    system("%TOPDIR%/bin/report-day $yyyymmdd");
}

# Main

&get_date_strings();
&save_files();
&do_report();
