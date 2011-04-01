#! /usr/bin/perl

use strict;

use Date::Format;

my(%previous);
my(%prev_l);

while (<>) {
    @_ = split;

    if (! /^[0-9]/) {
	next;
    }
    if ($_[1] eq "Reboot") {
	next;
    }
    my $t = $_[0];
    my $v = $_[1];

    if (defined($previous{$v})) {
	my $delta_t = $t - $previous{$v};
	if ($delta_t > 300 || $delta_t < 0) {
	    printf("%d", $delta_t);
	    print "\n";
	    foreach my $l ($prev_l{$v}, $_) {
		my @f = split(/\s+/, $l);
		printf("%s %s %s\n",
		       time2str("%a %b %e %T %Y", $f[0]),
		       $f[1],
		       $f[2]);
	    }
	}
    }
    $previous{$v} = $t;
    $prev_l{$v} = $_;
}
