#! %PERL%
#
# $Id$
#

#
# Produce a report of this month's upgrades
#

push(@INC, "%LIBDIR%");

require 'unctime.pl';
require 'pretty-ios.pl';


# Is the two time strings (form "Mon Jul 29 12:40:53 1996") close
# within X seconds?

sub close_times {
    my($a, $b, $x) = @_;
    my($a_t, $b_t);
    
    $a_t = &unctime($a);
    $b_t = &unctime($b);

    if ($a_t > $b_t) {
	return ( ($a_t - $b_t) <= $x );
    } else {
	return ( ($b_t - $a_t) <= $x );
    }
}

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
	$cur_software{$f} = $desc;
	$old_software{$f} = $desc;
	undef $desc;
    }
    closedir (dir);
}

# Read a day's worth of data, store results in the globals
#
# $restarts{$rtr}	number of restarts
# $reload_date{$rtr}	remember last reload time
# $upgraded{$rtr}	upgraded?
# $software{$rtr}	string of versions run on this day; separator: ^Q
# $reason{$rtr}		reason for last restart
# 
# Return date of last entry seen a'la "Oct 08".

sub read_day_data {
    my($in) = @_;
    my($rtr, $desc, @a, $day);

    while(<$in>) {
	chop; split;
	$rtr = $_[5];
	$day = $_[1] . " " . $_[2]; # "prettyprinted" date a'la "Oct 08"
	if (/reloaded: (.*)/) {
	    @a = split(/[ \t\n]+/, $1);
	    if ($_[0] eq $a[0] &&
		$_[1] eq $a[1] &&
		$_[2] eq $a[2])	# same date
	    {
		$recent_restart{$rtr} = 1;
		if (! defined $restarts{$rtr}) {
		    $restarts{$rtr} = 1;
		} else {
		    if (defined $reload_date{$rtr} &&
			! &close_times($1, $reload_date{$rtr}, 5))
		    {
			$restarts{$rtr}++;
		    }
		}
	    }
	    $reload_date{$rtr} = $1;
	} elsif (/uptime: (.*)/) {
	    $uptime{$rtr} = $1;
	} elsif (/software: (.*)/) {
	    if (/\#$/) {
		while(<in>) {
		    if (/^\#$/) {
			$desc =~ s/\r//g;
			last;
		    }
		    $desc .= $_;
		}
	    } else {
		$desc = sprintf("%s\n", $1);
	    }
	    if (defined $cur_software{$rtr} &&
		$cur_software{$rtr} ne $desc)
	    {
		if (defined($upgraded{$rtr})) {
		    $software{$rtr} .= "" . $desc;
		} else {
		    $software{$rtr} = $desc;
		}
		$upgraded{$rtr} = 1;
		$cur_software{$rtr} = $desc;
	    }
	    undef $desc;
	} elsif (/restart reason: (.*)/) {
	    $reason{$rtr} = $1;
	}
    }
    return $day;
}

sub report_day {
    my($day) = @_;
    my(@report, $rtr);
    my($old, $sw, @sw);
    
    foreach $rtr (keys %upgraded) {
	$old = $old_software{$rtr};
	@sw = split(//, $software{$rtr});
	foreach $sw (@sw) {
	    push(@report,
		 sprintf("%-6s %-15s from %-23s to %-23s\n",
			 $day,
			 $rtr,
			 &pretty_desc($old),
			 &pretty_desc($sw)
			 ));
	    $old = $sw;
	    $restarts{$rtr} = 0;
	}
	$old_software{$rtr} = $sw[$#sw];
    }
    undef %upgraded;
    return @report;
}


sub process_day {
    my($daydir) = @_;
    my($lf, $day);

    $lf = $daydir . "/ver-watch.log";

    open(in, $lf) || die "Could not open $lf: $!\n";
    $day = &read_day_data(in);
    close(in);
    return $day;
}

sub process_month {
    my($month) = @_;
    my(@report, $day, $daydir, $d);
    
    $daydir = $LOGTREE . "/" . $month . "/01";
    
    &get_start_software($daydir); # first day in month
    
    opendir(d, $LOGTREE . "/" . $month) ||
	die "Could not open month directory for $month: $!";
    while ($d = readdir(d))
    {
	if ($d eq "." || $d eq "..") { next; }
	$daydir = $LOGTREE . "/" . $month . "/" . $d;
	$day = &process_day($daydir);
	push (@report, &report_day($day));
    }
    return @report;
}

sub usage {
    printf(STDERR "usage: $0 yyyy-mm\n");
    exit(1);
}


#
# Main
#

$LOGTREE = "%TOPDIR%/ver-watch/logs";

if ($#ARGV != 0) {
    &usage();
}
$month = $ARGV[0];

@report = &process_month($month);

while($line = shift(@report)) {
    printf("%s", $line);
}
