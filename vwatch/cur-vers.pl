#!/usr/bin/perl

# $Id$

# Produce report of current software verions on the monitored routers.

require 'config.pl';
require 'pretty.pl';

sub get_start_software {
    local($daydir) = @_;
    local($dn, $f, $fn, $desc);
    
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
    local($in) = @_;
    local($rtr, $desc);

    while(<$in>) {
	chop; split;
	$rtr = $_[5];
	if (/software: (.*)/) {
	    if (/\#$/) {
		while(<in>) {
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
    local($rtr);

    open(out, "|sort -b +1 -2");
    foreach $rtr (keys %software) {
	printf(out "%-15s %s\n", $rtr, &pretty_desc($software{$rtr}));
    }
    close(out);
}

#
# Main
#

$today = $LOGTREE . "/today";

&get_start_software($today);
open(in, $today . "/ver-watch.log") ||
    die "Could not open today/ver-watch.log: $!";
&read_day_data(in);
close(in);
&report();

