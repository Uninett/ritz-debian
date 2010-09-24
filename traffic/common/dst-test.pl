#! /usr/bin/perl

# $Id$

use Time::Local;
use Date::Parse;

while (<>) {
    @f = split;

    $t0 = timelocal(strptime(sprintf("%s %s %s 00:00:00",
				     $f[0], $f[1], $f[2])));
    $t1 = timelocal(strptime(sprintf("%s %s %s 23:30:00",
				     $f[0], $f[1], $f[2])));
    $diff = $t1 - $t0;

    if ($diff < 23 * 3600) {
	printf("Date shifts to DST in local time zone, diff is %f\n",
	       $diff / 3600);
    } elsif ($diff > 24 * 3600) {
	printf("Date shifts from DST in local time zone, diff is %f\n",
	       $diff / 3600);
    } else {
	printf("Not shift to DST, diff is %f\n", $diff / 3600);
    }

    foreach my $a ("base", "lasttime", "dstcomp") {
	foreach my $v (keys %$a) {
	    $p->{"$a"}->{$v} = ${$a}{$v};
	}
    }


}
