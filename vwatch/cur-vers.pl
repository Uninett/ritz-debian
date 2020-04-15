#! %PERL%
#
# $Id$
#

#
# Produce report of current software verions on the monitored devices.
#

use strict;

push(@INC, "%LIBDIR%");
push(@INC, "%TOPDIR%/conf");

require 'zino-config.pl';
require 'pretty-ios.pl';

sub get_start_software {
    my($daydir) = @_;
    my($dn, $f, $fn, $desc);
    our(%software, %old_software);
    
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
	chomp $desc;
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
    our(%software);

    while(<$in>) {
	chop;
	@_ = split;
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

sub dissect_junos_version {
    my($v) = @_;
    my(%v);

    if ($v =~ /(\d+)\.(\d+)X(\d+)-D(\d+)\.(\d+)/o) {
	$v{"major"} = $1;
	$v{"minor"} = $2;
	$v{"rtype"} = "X";
	$v{"rev"} = $3;
	$v{"mrev"} = $4 . "." . $5;
	return %v;
    }

    if ($v =~ /(\d+)\.(\d+)R(\d+)-S(\d+)\.(\d+)/o) {
	$v{"major"} = $1;
	$v{"minor"} = $2;
	$v{"rtype"} = "RS";
	$v{"rev"} = $3;
	# Make larger than any other minor-rev, only used for comparison
	$v{"mrev"} = ($4 + 100) . "." . $5;
	return %v;
    }

    if ($v =~ /(\d+)\.(\d+)R(\d+)-S(\d+)/o) {
	$v{"major"} = $1;
	$v{"minor"} = $2;
	$v{"rtype"} = "RS";
	$v{"rev"} = $3;
	# Make larger than any other minor-rev, only used for comparison
	$v{"mrev"} = ($4 + 100);
	return %v;
    }

    if ($v =~ /(\d+)\.(\d+)([FRS])(\d+)\.(\d+)/o) {
	$v{"major"} = $1;
	$v{"minor"} = $2;
	$v{"rtype"} = $3;
	$v{"rev"} = $4;
	$v{"mrev"} = $5;
	return %v;
    }
    return undef;
}

sub cmp_versions {
    my($ta, $tb, $a, $b) = @_;
    my(%a, %b);

    if ($ta ne $tb) {
	return $ta cmp $tb;
    }

    if ($ta eq "JunOS") {
	%a = &dissect_junos_version($a);
	%b = &dissect_junos_version($b);
	if (!defined($a{"major"}) || !defined($b{"major"})) {
	    return $a <=> $b;
	}
	if ($a{"major"} == $b{"major"}) {
	    if ($a{"minor"} == $b{"minor"}) {
		if ($a{"rtype"} == $b{"rtype"}) {
		    if ($a{"rev"} == $b{"rev"}) {
			return $a{"mrev"} <=> $b{"mrev"};
		    } else {
			return $a{"rev"} <=> $b{"rev"};
		    }
		} else {
		    return $a{"rtype"} <=> $b{"rtype"};
		}
	    } else {
		return $a{"minor"} <=> $b{"minor"};
	    }
	} else {
	    return $a{"major"} <=> $b{"major"};
	}
	
    } else {
	%a = &dissect_cisco_version($a);
	%b = &dissect_cisco_version($b);
	if (!defined($a{"major"}) || !defined($b{"major"})) {
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
    }
    return 0;
}

sub cmp_lines {
    my($one, $two) = @_;
    my(@a, @b);

    @a = split(/\s+/, $one);
    @b = split(/\s+/, $two);

    my $r = &cmp_versions($a[1], $b[1], $a[2], $b[2]);
    if ($r == 0) {
	return $a[0] cmp $b[0];
    } else {
	return $r;
    }
}

sub pretty_desc {
    my($desc) = @_;

    if ($desc =~ /IOS.*Version/ ||
	$desc =~ /GS.*Version/ ||
	$desc =~ /Cisco ONS/) {
	return &pretty_ios_desc($desc);
    }
    if ($desc =~ /HP.*revision/) {
	return &pretty_hp_desc($desc);
    }
    if ($desc =~ /Juniper Networks/) {
	return &pretty_junos_desc($desc);
    }
    return $desc;
}


sub report {
    my($rtr, $l);
    my(@ll, @sl);
    our(%software);

    foreach $rtr (keys %software) {
	push(@ll, sprintf("%-25s %s\n", $rtr, &pretty_desc($software{$rtr})));
    }
    @sl = sort { &cmp_lines($a, $b) } @ll;
    foreach $l (@sl) {
	print $l;
    }
}

#
# Main
#

our $LOGTREE = "%TOPDIR%/ver-watch/logs";

our $today = $LOGTREE . "/today";

&get_start_software($today);
my $f = $today . "/ver-watch.log";
my($IN);
open($IN, $f) || die "Could not open $f: $!";
&read_day_data($IN);
close($IN);
&report();

