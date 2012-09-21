#! %PERL%

# $Id$

# Post-process the "load-now.txt" file optionally produced by tail-stats,
# to sum up the traffic on a per-customer basis from the per-port stats
# in the load-now.txt file.  Output on stdout.
#
# Additionally, this relies on all customers being labeled "cust" in the
# customers description file named in the -c option.

push(@INC, "%LIBDIR%");
use lib qw(%LIBDIR%);

use Zino::conn qw(read_desc select_types %fullname %ports);

use Getopt::Std;


sub err {
    my($e) = @_;
    printf STDERR "%s\n", $e;
    exit 1;
}

sub read_load_now {
    our(%p_in, %p_out);
    our(%a_in, %a_out);

    open(IN, "%TOPDIR%" . "/reports/load-now.txt");
    while(<IN>) {
	chomp;
	@_ = split;
	$p_in{$_[0]} = $_[1];
	$p_out{$_[0]} = $_[2];
	$a_in{$_[0]} = $_[3];
	$a_out{$_[0]} = $_[4];
    }
    close(IN);
}

sub process {
    our(%ports);
    our(%p_in, %p_out, %a_in, %a_out);
    our(%in, %out);
    our(%ain, %aout);

    foreach my $k (&select_types("cust", keys %ports)) {
	foreach my $p (@{ $ports{$k} }) {
	    $in{$k} += $p_in{$p};
	    $out{$k}+= $p_out{$p};
	    $ain{$k} += $a_in{$p};
	    $aout{$k}+= $a_out{$p};
	}
    }
}

sub report {
    our(%in, %out);
    our(%ain, %aout);

    foreach my $k (keys %in) {
	# In Mbit/s
	printf("%-20s %12f %12f   %12f %12f\n", $k,
	       $in{$k} / 1000.0, $out{$k} / 1000.0,
	       $ain{$k}/ 1000.0, $aout{$k}/ 1000.0
	    );
    }
}

#
# Main
#

&getopts("c:");

if (! -f $opt_c) {
    &err("description file (-c file) not readable; $opt_c");
}
&read_desc($opt_c);

&read_load_now();

&process();
&report();

