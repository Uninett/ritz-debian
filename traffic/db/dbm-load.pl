#!%PERL%
#
# $Id$
#

# Load a dbm database, input is <key> <value> pairs 
# separated by whitespace.
# Argument is base name of dbm file to open/create.

if ($#ARGV < 0) {
    printf(STDERR "usage: dbm-load.pl <dbm-base>\n");
    exit(1);
}

$f = $ARGV[0];
shift;

dbmopen(%db, $f, 0666);
while (<>) {
    chop;
    @_ = split(/[ \t\n]+/, $_, 2);
    $db{$_[0]} = $_[1];
}
dbmclose(%db);
