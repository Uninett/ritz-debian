#! %PERL%

#
# $Id$
#

use strict;

use lib "/a/traffic/lib";
require "search.pl";
require "read-5m-sum.pl";
require "db-lookup.pl";
require "date.pl";
require "utils.pl";

use Data::Dumper;

main() if not caller();

sub main {
    use Getopt::Std;
    our($opt_d, $opt_n);

    &getopts("d:n:");

    if (!$opt_d) {
	die "Must specify datespec\n";
    }

    if (!$opt_n) {
	die "Must specify name(s) of ports (divided by '+')";
    }
    
    my @results = &get_5m_sum($opt_d, $opt_n);
    print STDERR Dumper @results;
}

sub get_5m_sum {
    our($opt_d, $opt_n) = @_;
    my(@results);

    if ($opt_n =~ / /) {
	# web + -> ' ' in URLs...
	$opt_n =~ s/ /+/g;
    }

    my($tm, $nd) = &decode_datespec($opt_d);

    for my $d (0 .. $nd-1) {
	my $date = &tm_to_date($tm + $d * 86400);

	my($iov, $oov);
	our(%base, %count, %sample_time, $max_sample, $ifspeed);
	undef %base, %count, %sample_time, $max_sample, $ifspeed;

	my $err = &read_5m_sum($opt_n, $date);
	if ($err ne "") {
	    die $err;
	}

	if (defined($base{"ifHCInOctets"})) {
	    $iov = "ifHCInOctets";
	    $oov = "ifHCOutOctets";
	} else {
	    $iov = "ifInOctets";
	    $oov = "ifOutOctets";
	}

	for(my $i = 1; $i <= $max_sample; $i++) {
	    my $td = $sample_time{$i} - $sample_time{$i-1};
	    my $ir = $count{$iov,$i} * 8 / ($td * 3600.0);
	    my $or = $count{$oov,$i} * 8 / ($td * 3600.0);
	    
	    push(@results, [$tm + $sample_time{$i} * 3600.0,
			    $ir, $or]);
	}
    }
    return @results;
}

1;
