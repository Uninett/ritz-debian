#
# $Id$
#

# Prettyprint/abbreviate "system description",
# leave essential information only for those variants
# we have been tought to condense.

sub pretty_desc {
    my($desc) = @_;

    if ($desc =~ /IOS.*\(([^\)]+)\), Version ([^,\n]+),/) {
	$desc = "$2 $1";
    }
    if ($desc =~ /IOS.*\(([^\)]+)\),.*Version ([^ ]+) /) {
	$desc = "$2 $1";
    }
    if ($desc =~ /GS.*\(([^\)]+)\), Version ([^,]+),/) {
	$desc = "$2 $1";
    }
    if ($desc =~ /(HP[0-9]+[A-Z]) .*\(([^\)]+)\), revision ([^,]+),/) {
	$desc = "$3 $1 $2";
    }
    return $desc;
}

1;
