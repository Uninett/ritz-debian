#!/usr/bin/perl
# $Id$
use strict;
use warnings;

package Zino;
use Data::Dumper;
use POSIX qw(strftime);
use Digest::SHA qw/sha1_hex/;
use Net::Telnet ();
use Exporter;
use vars qw($VERSION @EXPORT);

$VERSION     = '0.02';
use base 'Exporter';
@EXPORT = ();

__PACKAGE__->run() unless caller();

sub run {
    my %config = ritz_config($ENV{HOME}.'/.ritz.tcl');
    my ($user, $secret) = @config{'User', 'Secret'};
    my ($host, $port) = @config{'Server', 'Port'};

    die "Unable to contact zino without username and password" 
        unless (defined $user and defined $secret);
    local $|;
    print strftime("[%Y-%m-%d %H:%M:%S] Checking zino...\n", localtime);
    my $result;
    my $zino = init($host, $port);
    login($zino, $user, $secret);
    # Get single element from returned id array
    my @caseids = caseids($zino);
    die "Zino didn't return any caseids" unless @caseids;
    # Get scalar value of array, ie number of results
    foreach my $case (@caseids) {
        my %attrs = getattrs( $zino, $case);
        if ($attrs{type} eq 'portstate' and $attrs{portstate} eq 'down') {
            # print map "<$_>: $attrs{$_}\n", keys %attrs;
            printf "Interface %s on router %s is down\n", $attrs{port}, $attrs{router};
        }
        if ($attrs{type} eq 'reachability' and $attrs{reachability} eq 'unreachable') {
            printf "Router %s is unreachable\n", $attrs{router};
        }
    }
    logout($zino);

}

#### subs ####

sub init {
    my($host, $port) = @_;
    my $zino = new Net::Telnet (Telnetmode => 0, 
                                Timeout => 20);

    $zino->open(
                Host => $host,
                Port => $port,
               );

    return $zino;
}

sub login {
    my ($zino, $user, $secret) = @_;
    my $challenge_line = $zino->getline;

    if ($challenge_line =~ m/^200 (\w+) /) {
        $zino->print("user $user " . sha1_hex("$1 $secret"));

        my $auth_result = $zino->getline;

        return 1 if $auth_result =~ m/^200/;
    }
    return 0;
}

sub caseids {
    my $zino = shift;
    my @caseids = ();

    $zino->print('CASEIDS');

    while (my $id = $zino->getline) {
        chomp $id;
        last if $id eq '.';
        next if $id =~ m/^304 /;

        push @caseids, $id;
    }

    return @caseids;
}

sub getlog {
    my ($zino, $id) = @_;
    my @logs = ();

    $zino->print('GETLOG ' . $id);

    while (my $log = $zino->getline) {
        chomp $log;
        last if $log eq '.';
        next if $log =~ m/^300 /;

        push @logs, $log;
    }

    return @logs;
}

sub getattrs {
    my ($zino, $id) = @_;
    my %attrs = ();

    $zino->print('GETATTRS ' . $id);

    while (my $line = $zino->getline) {
        chomp $line;
        last if $line eq '.';
        next if $line =~ m/^303 /;

        my ($attr, $val) = split /\s*:\s*/, $line;
        $attrs{$attr} = $val;
    }

    return %attrs;
}

sub logout {
    shift->print('QUIT');
}

sub ritz_config {
    my ($file) = @_;
    $file ||= $ENV{'HOME'}.'/.ritz.tcl';
    my %config;
    my $fh;
    open $fh, "$file" or die "Unable to open file $file: $!";
    while (<$fh>) {
        if (m/^set\s(\w+)\s+(\S+)/) {
            $config{$1} = $2;
        }
    }
    close $fh;
    return %config;
}
