#! %PERL%
#
# $Id$
#

#
# Produce a report of this month's restarts
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

# Read a day's worth of data, store results in the globals
#
# $restarts{$rtr}	number of restarts
# $reload_date{$rtr}	remember last reload time
# $upgraded{$rtr}	upgraded?
# $software{$rtr}	current software version
# $reason{$rtr}		reason for last restart
# 
# Return array containing report of all reload events incl. reason

sub process_log {
    my($in) = @_;
    my($rtr, $desc, @a, $day);
    my($new_reload, @report);

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
		    $new_reload = 1;
		} else {
		    if (defined $reload_date{$rtr} &&
			! &close_times($1, $reload_date{$rtr}, 5))
		    {
			$restarts{$rtr}++;
			$new_reload = 1;
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
		$desc = $1;
	    }
	    if (defined $software{$rtr} &&
		$software{$rtr} ne $desc)
	    {
		$upgraded{$rtr} = 1;
	    }
	    $software{$rtr} = $desc;
	    undef $desc;
	} elsif (/restart reason: (.*)/) {
	    $reason{$rtr} = $1;
	    if ($new_reload) {
		@a = split(/ /, $reload_date{$rtr});
		push(@report,
		     sprintf("%s %s %s %-15s: %s\n",
			     $a[1], $a[2], $a[3],
			     $_[5], $reason{$rtr}));
	    }
	    $new_reload = 0;
	}
    }
    return @report;
}

sub process_day {
    my($daydir) = @_;
    my($lf, @report);

    $lf = $daydir . "/ver-watch.log";

    open(in, $lf) || die "Could not open $lf: $!\n";
    @report = &process_log(in);
    close(in);
    return @report;
}

sub process_month {
    my($month) = @_;
    my(@report, $day, $daydir, $d);
    
    $daydir = $LOGTREE . "/" . $month . "/01";
    
#   &get_start_software($daydir); # first day in month
    
    opendir(d, $LOGTREE . "/" . $month) ||
	die "Could not open month directory for $month: $!";
    while ($d = readdir(d))
    {
	if ($d eq "." || $d eq "..") { next; }
	$daydir = $LOGTREE . "/" . $month . "/" . $d;
	push (@report, &process_day($daydir));
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
