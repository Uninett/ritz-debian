#! %PERL%
#
# $Id$
#

#
# Produce report of current software verions on the monitored devices.
#

push(@INC, "%LIBDIR%");
push(@INC, "%TOPDIR%/conf");

require 'config.pl';
require 'pretty-ios.pl';

sub get_start_software {
    my($daydir) = @_;
    my($dn, $f, $fn, $desc);
    
    $dn = $daydir . "/descs";
    opendir (dir, $dn) || die "Could not opendir $dn: $!";
    while ($f = readdir(dir)) {
	if ($f eq "." || $f eq "..") { next; }
	$fn = $dn . "/" . $f;
	open(in, $fn) || die "Could not open $fn: $!";
	while(<in>) {
	    $desc .= $_;
	}
	close(in);
	$desc =~ s/\r//g;
	$software{$f} = $desc;
	$old_software{$f} = $desc;
	undef $desc;
    }
    closedir (dir);
}

# Read a day's worth of data, store results in the global
#
# $software{$rtr}	current software version

sub read_day_data {
    my($in) = @_;
    my($rtr, $desc);

    while(<$in>) {
	chop; split;
	$rtr = $_[5];
	if (/software: (.*)/) {
	    if (/\#$/) {
		while(<$in>) {
		    if (/^\#$/) {
			$desc =~ s/\r//g;
			last;
		    }
		    $desc .= $_;
		}
	    } else {
		$desc = $1;
	    }
	    $software{$rtr} = $desc;
	    undef $desc;
	}
    }
}

sub report {
    my($rtr);

    open(out, "|sort -b +1 -2");
    foreach $rtr (keys %software) {
	printf(out "%-25s %s\n", $rtr, &pretty_desc($software{$rtr}));
    }
    close(out);
}

#
# Main
#

$LOGTREE = "%TOPDIR%/ver-watch/logs";

$today = $LOGTREE . "/today";

&get_start_software($today);
$f = $today . "/ver-watch.log";
open(IN, $f) || die "Could not open $f: $!";
&read_day_data(IN);
close(IN);
&report();

