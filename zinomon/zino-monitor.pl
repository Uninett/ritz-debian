#!/usr/bin/perl
# $Id$
use strict;
use warnings;
use Digest::SHA qw/sha1_hex/;
use Net::Telnet ();
use Data::Dumper;
use POSIX qw(strftime);
use Zino;

# my ($user, $secret) = do 'secret.pl';

my %config = Zino::ritz_config($ENV{HOME}.'/.ritz.tcl');
my ($user, $secret) = @config{'User', 'Secret'};
my ($host, $port) = @config{'Server', 'Port'};

die "Unable to contact zino without username and password" 
    unless (defined $user and defined $secret);

local $|;
print strftime("[%Y-%m-%d %H:%M:%S] Checking zino...\n", localtime);
my $result;
eval {
    my $zino = Zino::init($host, $port);

    Zino::login($zino, $user, $secret);

    # Get singel element from returned id array
    my ($test_id) = Zino::caseids($zino);

    die "Zino didn't return caseids" if not defined $test_id;

    # Get scalar value of array, ie number of results
    $result = scalar Zino::getlog( $zino, $test_id);

    die "Zino didn't return log for CASEID $test_id" if $result == 0;

    Zino::logout($zino);
};
if ($@) {
    printf STDERR ("[%s] Error: %s ", strftime("%Y-%m-%d %H:%M:%S", localtime), $@);
    exit 1;
}
if ($result) {
    print "Got $result logs\n";
    exit 0;
} else {
    printf STDERR ("Mangler fornuftig respons fra zino");
    exit 1;
}
