#!/usr/bin/perl

# $Id$

# Daily script for Cisco software version watcher.

require 'config.pl';

sub get_date_strings {
    local($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($^T);
    
    $ym_str = sprintf("%4d-%02d", $year+1900, $mon+1);
    $day_str = sprintf("%02d", $mday);
    $yyyymmdd = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
}

sub save_logs {
    local($logtree, $mdir, $ddir, $today, $cmd, $ret);
    
    $logtree = $LOGTREE;

    $mdir = $logtree . "/" . $ym_str;
    if ( ! -d $mdir ) {
	if (mkdir ($mdir, 0755) != 1) {
	    die "Could not create $mdir: $!\n";
	}
    }

    $ddir = $mdir . "/" . $day_str;

    if ( ! -d $ddir ) {
	if (mkdir ($ddir, 0755) != 1) {
	    die "Could not create $ddir: $!\n";
	}
    }

    $today = $logtree . "/today";

    $cmd = "/bin/mv $today/* $ddir";
    $ret = system($cmd) / 256;
    if ($ret != 0) {
	die "Could not move files/dirs to $ddir\n";
    }

    if (mkdir ($today . "/descs", 0755) != 1) {
	die "Could not recreate $today/descs\n";
    }
    system("touch $today/ver-watch.log"); # create empty file
}

sub report_and_mail {
    local($ddir, $rfn, $cmd);

    $ddir = $LOGTREE . "/" . $ym_str . "/" . $day_str;

    $rfn = $ddir . "/report";
    system("$BIN/report-day.pl $ym_str $day_str > $rfn");

    $cmd = $MAILPROG;
    $cmd .= " -s ";
    $cmd .= "\"$ym_str-$day_str router upgrade/restart report\" ";
    $cmd .= $MAILTO;
    $cmd .= " <$rfn";
    
    if (-s $rfn) {		# Skip empty reports
	system($cmd);
    }
}

#
# Main
#

&get_date_strings();
&save_logs();
&report_and_mail();
