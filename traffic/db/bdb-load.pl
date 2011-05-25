#!%PERL%
#
# $Id$
#

# Load a Berkeley DB database, input is <key> <value> pairs 
# separated by whitespace.
# Argument is base name of Berkeley DB file to open/create.

use strict;
use BerkeleyDB;

our(@ARGV);

if ($#ARGV < 0) {
    printf(STDERR "usage: bdb-load.pl <bdb-base>\n");
    exit(1);
}

my $f = $ARGV[0];
shift;
my(%db);

tie(%db, 'BerkeleyDB::Hash',
    -Filename => $f,
    -Flags => DB_CREATE) 
    or die "Could not open $f: $! $BerkeleyDB::Error\n";

while (<>) {
    chop;
    @_ = split(/[ \t\n]+/, $_, 2);
    $db{$_[0]} = $_[1];
}
untie(%db);
