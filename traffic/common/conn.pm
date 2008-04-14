# $Id$

# conn-common.pl converted into a module.

# Parse customer description file
# Fields are separated by !
# Fields are:
#   short name (will be used in titles in plots etc)
#   full name  (official name of customer / connection)
#   categories (comma-separated list of categories this is a member of)
#   portlist   (comma-separated list of logical ports this customer /
#   	        connection has had over the entire history)
#
# read_desc leaves results in following hashes:
#   fullname{shortname}   Full name of customer / connection
#   types{shortname}      Ref to array listing categories it is member of
#   ports{shortname}      Ref to array of logical port names this customer /
#                         connection has or has had up through its history
#

package Zino::conn;

use Exporter ();
@ISA = qw(Exporter);
@EXPORT = qw(read_desc select_types);
@EXPORT_OK = qw(fullname ports types);

# Local utility functions:

sub trimws
{
    my($s) = @_;

    $s =~ s/\s//g;
    return $s;
}

sub trimws_fb
{
    my($s) = @_;

    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    return $s;
}

# Exported interfaces

our(%fullname, %ports, %types);

sub read_desc
{
    my($f) = @_;
    our(%fullname, %ports, %types);

    undef %fullname;
    undef %ports;
    undef %types;

    open(IN, $f) || die "Could not open $f for read: $!";
    while(<IN>) {
	chomp;
	my(@f) = split(/!/);
	my($sn) = &trimws($f[0]);
	my($fullname) = &trimws_fb($f[1]);
	my($typestring) = &trimws($f[2]);
	my($portnames) = &trimws($f[3]);

	$fullname{$sn} = $fullname;
	my(@pn, @tn);
	@pn = split(/,/, $portnames);
	@tn = split(/,/, $typestring);

	$ports{$sn} = \@pn;
	$types{$sn} = \@tn;
    }
    close(IN);
}

# Include all matching types,
# but let !type override to not match

sub select_types {
    my($expr, @all) = @_;
    my(@incl, @excl, @res);
    our(%types);

    @res = @excl = @incl = ();

    foreach my $e (split(/,/,$expr)) {
	if ($e =~ /!(.*)$/) {
	    push(@excl, $1);
	} else {
	    push(@incl, $e);
	}
    }
    my($found);
    foreach my $sn (@all) {
	$found = 0;
	if ($#incl == -1) {
	    $found = 1;
	} else {
	    foreach my $i (@incl) {
		foreach my $t (@{ $types{$sn} }) {
		    if ($i eq $t) {
			$found = 1;
		    }
		}
	    }
	}
	foreach my $e (@excl) {
	    foreach my $t (@{ $types{$sn} }) {
		if ($e eq $t) {
		    $found = 0;
		}
	    }
	}
	if ($found) {
	    push(@res, $sn);
	}
    }
    return @res;
}

1;
