#! %PERL%

# $Id$

# Convert from old-style timestamped data files to new-style data
# files with timestamps in seconds UTC since 1 jan 1970 00:00.

use Time::Local;
use Date::Parse;
use Date::Format;
use Getopt::Std;
use File::Basename;

use strict;

sub convert {
    my($IN, $OUT) = @_;
    my($h0_seen) = 0;
    my($t0);
    my($s0, $t);
    my($dstcomp, %dstcomp, %lasttime, %seen);

    print $OUT "Version 1\n";
    while(<$IN>) {
	split;

	if (/^Version/) {
	    next;
	} elsif (/^if/) {
	    print $OUT $_;
	    next;
	}
	if (/^$/) {
	    next;
	}
	if (/^[0-9]/) {		# already converted?
	    print $OUT $_;
	    next;
	}
	my($h, $m, $s) = split(/:/, $_[3]);
	
	if (!$h0_seen) {
	    if ($h == 0) {
		$h0_seen = 1;

		$t0 = str2time(
		    sprintf("%s %s %s %s 00:00:00",
			    $_[0], $_[1], $_[2], $_[4]));
		$s0 = $h * 3600 + $m * 60 + $s;
		$t = $t0 + $s0;

		my($t1, $t2);
		$t1 = timelocal(strptime(sprintf("%s %s %s 00:00:00",
						 $_[1], $_[2], $_[4])));
		$t2 = timelocal(strptime(sprintf("%s %s %s 23:30:00",
						 $_[1], $_[2], $_[4])));
		my($diff) = $t2 - $t1;
		if ($diff < 23 * 3600) {
		    $dstcomp = -3600; # to daylight saving
		} elsif ($diff > 24 * 3600) {
		    $dstcomp = 3600; # from daylight saving
		} else {
		    $dstcomp = 0;
		}

	    } else {
		$t = str2time(join(' ', @_[0..4]));
	    }
	} else {
	    $s0 = $h * 3600 + $m * 60 + $s;
	    $t = $t0 + $s0;
	}

	if ($_[5] eq "Reboot") {
	    my($rt) = str2time(join(' ', @_[7..11]));
	    printf($OUT "%d Reboot at %d\n", $t, $rt);
	    next;
	}

	my($v) = $_[5];		# includes instance
	my($val) = $_[6];

	if (defined($lasttime{$v})) {
	    if (abs($lasttime{$v} - $t) > 3000 &&
		abs($lasttime{$v} - $t) < 7200) { # assumes < 600s poll interval
		foreach my $v (keys %seen) {
		    $dstcomp{$v} = $dstcomp;
		}
	    } 
	}
	$lasttime{$v} = $t;

	$t += $dstcomp{$v};
	$seen{$v} = 1;

	printf($OUT "%d %s %s\n", $t, $v, $val);
    }
}

sub convert_file {
    my($f) = @_;
    our($opt_n, $opt_N);
    my($IN, $OUT);
    my($nf) = $f . ".new";
    my($of) = $f . ".old";
    my($wasgz) = 0;
    my($d, $b, $nogz);

    if ($f =~ /\.gz$/) {
	$wasgz = 1;
	$d = dirname($f);
	$b = basename($f, ".gz");
	$nogz = $d . "/" . $b;
	$nf = $nogz . ".new";
	$of = $nogz . ".old";
	open($IN, "gzcat $f |") || die "Could not gzcat $f: $!";
    } else {
	open($IN, $f) || die "Could not read $f: $!";
    }
    open($OUT, ">" . $nf) || die "Could not write $nf: $!";
    &convert($IN, $OUT);
    close($IN);
    close($OUT);

    if (!defined($opt_N)) {
	rename($f, $of);
	if ($wasgz) {
	    rename($nf, $nogz);
	    system("gzip $nogz");
	} else {
	    rename($nf, $f);
	}
    }
    if (!defined($opt_n)) {
	unlink($of);
    }
}

#
# Main
#

our($opt_n, $opt_N);

getopts("nN");

foreach my $f (@ARGV) {
    &convert_file($f);
}
