#! %PERL%
#
# $Id$
#

#
# Produce report of current software verions and uptimes
# on the monitored devices.
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

sub get_uptimes {
    my($daydir) = @_;
    my($dn, $f, $fn, $up);

    $dn = $daydir . "/uptime";
    opendir (dir, $dn) || die "Could not opendir $dn: $!";
    while ($f = readdir(dir)) {
	if ($f eq "." || $f eq "..") { next; }
	$fn = $dn . "/" . $f;
	open(in, $fn) || die "Could not open $fn: $!";
	$uptime{$f} = <in>;
	close(in);
    }
}

sub uptime {
    my($rtr) = @_;
    my($u) = $uptime{$rtr};
    my($d, $h, $m, $s, $hs);

    if (!defined($u)) { return ""; }

    $hs = $u % 100;
    $u = ($u / 100);
    $s = $u % 60;
    $u = ($u / 60);
    $m = $u % 60;
    $u = int($u / 60);
    $h = $u % 24;
    $u = int($u / 24);
    $d = $u;

    return sprintf("%dd %2d:%02d:%02d.%02d",
		   $d, $h, $m, $s, $hs);
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

sub dissect_cisco_version {
    my($v) = @_;
    my(%v);

    if ($v =~ /(\d+)\.(\d+)\(([^\)]+)\)([A-Z]*)(\d*)/o) {
	$v{"major"} = $1;
	$v{"minor"} = $2;
	$v{"rev"} = $3;
	$v{"train"} = $4;
	$v{"trainrev"} = $5;
	return %v;
    }
    return undef;
}

sub cmp_versions {
    my($a, $b) = @_;
    my(%a, %b);

    %a = &dissect_cisco_version($a);
    %b = &dissect_cisco_version($b);
    if (!defined(%a) || !defined(%b)) {
	return $a <=> $b;
    }
    if ($a{"major"} == $b{"major"}) {
	if ($a{"minor"} == $b{"minor"}) {
	    if ($a{"train"} eq $b{"train"}) {
		if ($a{"rev"} == $b{"rev"}) {
		    return $a{"trainrev"} <=> $b{"trainrev"};
		} else {
		    return $a{"rev"} <=> $b{"rev"};
		}
	    } else {
		return $a{"train"} cmp $b{"train"};
	    }
	} else {
	    return $a{"minor"} <=> $b{"minor"};
	}
    } else {
	return $a{"major"} <=> $b{"major"};
    }
    return 0;
}

sub cmp_lines {
    my($one, $two) = @_;
    my(@a, @b);

    @a = split(/\s+/, $one);
    @b = split(/\s+/, $two);

    my $r = &cmp_versions($a[1], $b[1]);
    if ($r == 0) {
	return $a[0] cmp $b[0];
    } else {
	return $r;
    }
}

sub report {
    my($rtr, $l);
    my(@ll, @sl);

    foreach $rtr (keys %software) {
	push(@ll, sprintf("%-25s %-36s %16s\n",
			  $rtr,
			  &pretty_desc($software{$rtr}),
			  &uptime($rtr)
			  ));
    }
    @sl = sort { &cmp_lines($a, $b) } @ll;
    foreach $l (@sl) {
	print $l;
    }
}

#
# Main
#

$LOGTREE = "%TOPDIR%/ver-watch/logs";

$today = $LOGTREE . "/today";

&get_start_software($today);
&get_uptimes($today);
$f = $today . "/ver-watch.log";
open(IN, $f) || die "Could not open $f: $!";
&read_day_data(IN);
close(IN);
&report();

