#! /usr/bin/perl

use strict;

use Date::Format;

my(%previous);
my(%prev_l);

while (<>) {
    @_ = split;

    if (! /^[0-9]/) {
	print; next;
    }
    if ($_[1] eq "Reboot") {
	my ($rt) = $_[3];
	printf("%s Reboot at %s\n",
	       time2str("%a %b %e %T %Y", $_[0]),
	       time2str("%a %b %e %T %Y", $rt));
	next;
    }

    printf("%s %s %s\n",
	   time2str("%a %b %e %T %Y", $_[0]),
	   $_[1], $_[2]);
}
