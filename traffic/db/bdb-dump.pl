#!%PERL%
#
# $Id$
#

# Dump a Berkeley DB database.  Output is <key> <value> pairs separated by
# a tab. Argument is base name of Berkeley DB file to dump.

use strict;
use BerkeleyDB;

our(@ARGV);

if ($#ARGV < 0) {
    printf(STDERR "usage: dbm-dump.pl <dbm-base>\n");
    exit(1);
}

my $f = $ARGV[0];
my(%db, $key, $val);

tie(%db, 'BerkeleyDB::Hash', -Filename $f)
    or die "Could not open $f: $! $BerkeleyDB::Error\n";

while (($key,$val) = each %db) {
    printf ("%s\t%s\n", $key, $val);
}
untie(%db);
