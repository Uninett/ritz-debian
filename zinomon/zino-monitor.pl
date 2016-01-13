#!/usr/bin/perl
# $Id$
use strict;
use warnings;
use Digest::SHA qw/sha1_hex/;
use Net::Telnet ();
use Data::Dumper;
use POSIX qw(strftime);
use Zino;

sub log {
    my($s) = @_;

    printf("%s %s\n",
	   strftime("[%Y-%m-%d %H:%M:%S]", localtime),
	   $s);
}

# my ($user, $secret) = do 'secret.pl';

my %config = Zino::ritz_config($ENV{HOME}.'/.ritz.tcl');
my ($user, $secret) = @config{'User', 'Secret'};
my ($host, $port) = @config{'Server', 'Port'};

die "Unable to contact zino without username and password" 
    unless (defined $user and defined $secret);

local $| = 1;
&log("Checking zino...");
my $result;

eval {
    local $SIG{ALRM} = sub { die "alarm\n" };
    alarm 30;			# reasonable(?) time-out value

    my $zino = Zino::init($host, $port);

    &log("Connected");

    Zino::login($zino, $user, $secret);

    &log("Authenticated");

    # Get single element from returned id array
    my ($test_id) = Zino::caseids($zino);

    &log("Got case ID");

    if (!defined($test_id)) {
	my ($v) = Zino::version($zino);
	if (!defined($v)) {
	    die "Zino did not even return version number";
	}
	if ($v eq "") {
	    die "Zino returned empty version number";
	}
	if ($v !~ /^[0-9]/) {
	    die "Zino returned non-numeric first-digit version number: $v";
	}
	$result = "Zino: no open cases, version number returned is " . $v;
    } else {
	# Get scalar value of array, ie number of results
	my $count = scalar Zino::getlog( $zino, $test_id);

	&log("Got log for event $test_id, count $count");

	die "Zino didn't return log for CASEID $test_id" if $count == 0;

	$result = "Zino got " . $count . " logs";
    }
    Zino::logout($zino);

    &log("Logged out");

    alarm 0;
};
if ($@) {
    if ($@ eq "alarm\n") {
	printf STDERR ("[%s] Error: Zino timed out\n",
		       strftime("%Y-%m-%d %H:%M:%S", localtime));
    } else {
	printf STDERR ("[%s] Error: %s\n",
		       strftime("%Y-%m-%d %H:%M:%S", localtime), $@);
    }
    exit 1;
}
if ($result) {
    print $result . "\n";
    exit 0;
} else {
    printf STDERR ("No reasonable response from Zino\n");
    exit 1;
}
