#!%PERL%
#
# $Id$
#

# Dump a dbm database.  Output is <key> <value> pairs separated by
# a tab. Argument is base name of dbm file to dump.

if ($#ARGV < 0) {
    printf(STDERR "usage: dbm-dump.pl <dbm-base>\n");
    exit(1);
}

$f = $ARGV[0];
dbmopen(%db, $f, 0666);
while (($key,$val) = each %db) {
    printf ("%s\t%s\n", $key, $val);
}
dbmclose(%db);
