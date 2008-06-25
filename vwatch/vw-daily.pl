#! %PERL%
#
# $Id$
#

#
# Daily script for Cisco software version watcher.
# Rotate logs, mail report.
#

sub get_date_strings {
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($^T);
    
    $ym_str = sprintf("%4d-%02d", $year+1900, $mon+1);
    $day_str = sprintf("%02d", $mday);
    $yyyymmdd = sprintf("%04d-%02d-%02d", $year+1900, $mon+1, $mday);
}

sub save_logs {
    my($logtree, $mdir, $ddir, $today, $cmd, $ret);
    
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
    if (mkdir ($today . "/uptime", 0755) != 1) {
	die "Could not recreate $today/uptime\n";
    }
    system("touch $today/ver-watch.log"); # create empty file
}

sub report_and_mail {
    my($ddir, $rfn, $cmd);

    $ddir = $LOGTREE . "/" . $ym_str . "/" . $day_str;

    $rfn = $ddir . "/report";
    system("%BINDIR%/vw-day-report $ym_str $day_str > $rfn");

    if (-s $rfn) {
	open(OUT, "| %RAWSENDMAIL% $MAILTO") ||
	    die "Could not open sendmail: $!";
	printf(OUT "From: $MAILFROM\n");
	printf(OUT "To: $MAILTO\n");
	printf(OUT
	       "Subject: Device upgrade/restart report $ym_str-$day_str\n");
	printf(OUT "\n");

	open(IN, "$rfn");
	while(<IN>) {
	    print(OUT $_);
	}
	close(IN);
	close(OUT);
    }
}

sub getmail {
    my($f) = @_;
    my($str);

    open(IN, $f) || die "Could not open $f: $!";
    while(<IN>) {
	chomp;
	split(/=/, $_, 2);
	if ($_[1] =~ /^[\'\"]/) {
	    $_[1] = substr($_[1], 1);
	}
	if ($_[1] =~ /[\'\"]$/) {
	    chop($_[1]);
	}
	$str = "\$$_[0] = \$_[1];";
	eval $str;
    }
    close(IN);
}

#
# Main
#

$LOGTREE = "%TOPDIR%/ver-watch/logs";

&getmail($ENV{'HOME'} . "/.zino-mail");

&get_date_strings();
&save_logs();
&report_and_mail();
