#
# $Id$
#
# Convert a string of type "Mon Jul 29 12:40:53 1996"
# or "Mon Jul 19 12:40:53 MET DST 1996" to seconds since
# the epoch using timelocal().
#
# The time zone specified in the given string is ignored,
# and the time is assumed to be in the local time zone.

require 'timelocal.pl';

package unctime;

$month{'Jan'} = 0;
$month{'Feb'} = 1;
$month{'Mar'} = 2;
$month{'Apr'} = 3;
$month{'May'} = 4;
$month{'Jun'} = 5;
$month{'Jul'} = 6;
$month{'Aug'} = 7;
$month{'Sep'} = 8;
$month{'Oct'} = 9;
$month{'Nov'} = 10;
$month{'Dec'} = 11;

sub main'unctime {
    local($date) = @_;
    local(@a, @b);
    
    @a = split(/ /, $date);
    @b = split(/:/, $a[3]);
    return &main'timelocal($b[2], $b[1], $b[0],
			   $a[2], $month{$a[1]}, $a[$#a]-1900);
}

1;
