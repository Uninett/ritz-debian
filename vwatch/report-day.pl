#!/usr/bin/perl

# $Id$

# Produce daily report, store it and e-mail it.

require 'config.pl';
require 'unctime.pl';
require 'pretty.pl';


# Is the two time strings (form "Mon Jul 29 12:40:53 1996") close
# within X seconds?

sub close_times {
    local($a, $b, $x) = @_;
    local($a_t, $b_t);
    
    $a_t = &unctime($a);
    $b_t = &unctime($b);

    if ($a_t > $b_t) {
	return ( ($a_t - $b_t) <= $x );
    } else {
	return ( ($b_t - $a_t) <= $x );
    }
}


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
	chop($desc);		# remove last newline
	$software{$f} = $desc;
	$old_software{$f} = $desc;
	undef $desc;
    }
    closedir (dir);
}


sub process {
    local($daydir) = @_;
    local($lf, $rtr, $desc, @a);
    
    &get_start_software($daydir);

    $lf = $daydir . "/ver-watch.log";

    open(in, $lf) || die "Could not open $lf: $!\n";
    while(<in>) {
	chop; split;
	$rtr = $_[5];
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
		chop($desc);	# remove last newline
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
	}
    }
    close(in);
}

sub report {
    local($n, $rtr);

    $n = 0;
    foreach $rtr (keys %upgraded) {
	$n++;
	if ($n == 1) {
	    printf("Upgraded routers:\n\n");
	}
	printf("%-15s from %15s to %15s (%d restarts)\n",
	       $rtr,
	       &pretty_desc($old_software{$rtr}),
	       &pretty_desc($software{$rtr}),
	       $restarts{$rtr}
	       );
    }
    if ($n != 0) { printf("\n"); };

    $n = 0;
    foreach $rtr (keys %recent_restart) {
	if ($upgraded{$rtr}) {
	    if (!defined($reason{$rtr}) ||
		($reason{$rtr} =~ /power-on|reload/)) {
		next;		# no reason to chat about this one
	    }
	}
	$n++;
	if ($n == 1) {
	    printf("Restarted/crashed routers:\n\n");
	}
	printf("%-15s (%d total) current version %s\n",
	       $rtr,
	       $restarts{$rtr},
	       &pretty_desc($software{$rtr}));
	printf("%-15s last restart %s",
	       $rtr,
	       $reload_date{$rtr});
	if (defined($reason{$rtr})) {
	    printf("\n%-15s restart reason: %s",
		   $rtr, $reason{$rtr});
	}
	printf("\n");
    }
}

sub usage {

    printf(STDERR "usage: $0 yyyy-mm dd\n");
    exit(1);
}

sub getargs {
    
    if ($#ARGV != 1) {
	&usage();
    }
    return ($ARGV[0], $ARGV[1]);
}

#
# Main
#

($yyyy_mm, $dd) = &getargs();

$daydir = $LOGTREE . "/" . $yyyy_mm . "/" . $dd;

&process($daydir);
&report();
