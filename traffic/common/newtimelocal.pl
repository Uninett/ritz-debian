# newtimelocal.pl
# a better version of timelocal.pl
#
# (c) 1996 Dan Kogai (dankogai@dnsa.or.jp)
#
# Permission granted to use and modify this library so long as the
# copyright above is maintained, modifications are documented, and
# credit is given for any use of the library.
# 
# See pod after __END__ Section for details
#
# Usage:
#      $ltime = &timelocal($sec,$min,$hours,$mday,$mon,$year);
#      $ltime = &mktime($sec,$min,$hours,$mday,$mon,$year);
#      $ltime = &timegm($sec,$min,$hours,$mday,$mon,$year);
#
# Works just like the same old timelocal() and timegm().
# of timelocal.pl except;
# A)  Values out of range gets normalized unlike the original
# timelocal.pl which just dies with error.  This is convenient 
# when you need to get a time of past & future.
# B)  You can use dategm() if you only need date.


sub timelocal{ return &newtimelocal'timelocal(@_);}
sub mktime{ return &newtimelocal'timelocal(@_);}
sub timegm   { return &newtimelocal'timegm(@_);}

# Usage:
#      $days = &daysgm($mday,$mon,$year);
#
# Returns number of days since Epoch (1970/01/01 on Unix but
# could be different on other).  Unlike timegm
# and timelocal which returns error before 1970 and after 2038,
# This one works days beyond that.

sub daysgm   { return &newtimelocal'daysgm(@_);}

# normalize date
# 

sub normaldate{
    local($sc,$mi,$hr,$dy,$mo,$yr) = @_;
    local(@DinM) = (31,28,31,30,31,30,31,31,30,31,30,31);

    # normalize in advance
    
    $yr += int($mo / 12) ; $yr-- if ($mo < 0);
    $mo %= 12;
    
    # normalize mday
    
    $DinM[1] ++ if &newtimelocal::isleap($year);
    $dy = $DinM[$mo] if $DinM[$mo] < $dy;
    $dy = 1 if $dy < 1;

    return(gmtime(&timegm($sc,$mi,$hr,$dy,$mo,$yr)));
}

####   real definitions below

#  I rewrote the functions so it uses no local()

package newtimelocal;

$DAY              = 86400;
$HOUR             = 3600;
$MIN              = 60;
$SEC              = 1;
@m2yday           = (0,31,59,90,120,151,181,212,243,273,304,334);

#  Ad hoc patch for MacPerl which returns a funny value for gmtime(0);
#
if (defined $MacPerl::Version){
    $MAXINT       = 2 ** 32;
    $NOW          = time();
    $DAYS_TILL_EPOCH = &ADdays(1,0,1904);
    $TZDIFF       = &timegm(localtime(0)) - &timegm(gmtime(0));
    $MACDIFF      = $TZDIFF;
}else{
    $MAXINT           = 2 ** 31;
    @EPOCH            = gmtime(0);
    $DAYS_TILL_EPOCH  = &ADdays($EPOCH[3],$EPOCH[4],$EPOCH[5] + 1900);
    $TZDIFF           = &timegm(localtime(0));
    $MACDIFF          = 0;
}

sub timelocal{
    $tl_gm = &timegm(@_);
    return ($tl_gm == -1) ? -1 : $tl_gm - $TZDIFF;
}

sub timegm{
    ($tg_sc,$tg_mn,$tg_hr,$tg_dy,$tg_mo,$tg_yr) = @_;
    $tg_result = 
        &daysgm($tg_dy, $tg_mo, $tg_yr) * $DAY
            + $tg_hr * $HOUR + $tg_mn * $MIN + $tg_sc * $SEC + $MACDIFF;
    return ($tg_result < $MAXINT) ? $tg_result : -1;
}

sub daysgm{
	return &ADdays($_[0],$_[1],$_[2] + 1900) - $DAYS_TILL_EPOCH;
}
sub ADdays{
    
    ($dg_dy, $dg_mo, $dg_yr) = @_;
    
    # year and month gets normalized
    # so that timelocal accepts out-of-range values
        
    $dg_yr += int($dg_mo / 12) ; $dg_yr-- if ($dg_mo < 0);
    $dg_mo %= 12;
    
    $dg_dy--;
    
    return $dg_yr * 365 + $m2yday[$dg_mo] 
                + &numleap($dg_yr,$dg_mo) + $dg_dy;
}

sub numleap{
    ($nl_yr,$nl_mo) = @_;
    $result = int($nl_yr / 4) - int($nl_yr / 100) + int($nl_yr / 400);
    return (&isleap($nl_yr) && $nl_mo < 2) ? $result-1 : $result;
}

sub isleap{
    local($il_yr) = @_;
    return 0 unless ($il_yr % 4 == 0);
    return 1 unless ($il_yr % 100 == 0);
    return 0 unless ($il_yr % 400 == 0);
}

1;

__END__

=head1 NAME

newtimelocal.pl -- a better version of timelocal.pl package

=head1 SYNOPSIS

require 'newtimelocal.pl';

$ltime = &timelocal($sec,$min,$hours,$mday,$mon,$year);

$ltime = &mktime($sec,$min,$hours,$mday,$mon,$year);

$gtime = &timegm($sec,$min,$hours,$mday,$mon,$year);

$date  = &daysgm($mday,$mon,$year);

($sec,$min,$hours,$mday,$mon,$year)  = &normaldate($sec,$min,$hours,$mday,$mon,$year);

=head1 DESCRIPTION

newtimelocal.pl was written to correct the shortcomings of
timelocal.pl that comes with perl distributions.  Unlike C timelocal()
function that is available on various Unix, the original
timelocal() simply returns error when out-of-rage values are fed.
The timelocal() of newtimelocal.pl instead normalizes arguments so that
you can go like;

@now = localtime();
@now[3] -= 3;
$threedaysago = &timelocal(@now);

Without worring about the range.  newtimelocal.pl is also faster than
timelocal.pl since no "cheat" is involved.  I would like this
newtimelocal replaces the original in the next perl patch...

daysgm() retuns number of days passed since Epoch (1970/01/01 on most
Unix but the value of Epoch is sytem-dependent.  See BUGS for details).  
Use this function if date is the only question because this function
does not return error for days before Epoch and after 2038.  Also this
function is faster than timegm() and timelocal(); both functions use
daysgm() internally.

normaldate() forciblly fits arguments of timelocal() within range.
See BUGS for details of this function.

=head1 BUGS

=head2 Date Normalization

Argument normalization has a problem when you want to know "a month
ago" when the current date is 31st (or any day after 28/29th on
March).  For instance,

&daysgm(31,2-1,96) == &daysgm(2,2,96) != daysgm(29,1,96)

This is rather a feature than a bug since the case above tries to
yield "days since 1970/01/01 till 1996/02/31".  Since There is no
February 31st, it normalizes day and returns days for 1996/03/02.

Since a question "What is a date a month ago from March 31st?" is
ambiguous (it is not necessarily Februaly 28/29th) and this is how
timelocal() and mktime() of most C library behave,  I have left it as
is and instead added &normaldate(), which returns a normalized version
of timelocal()'s arguments.  

Remember, though, that normaldate() forces date of the month to fit 
within 1..I<last day of the month> no matter what (mday below 1 is set
to 1.  mday above max date of the month (28..31) set to the max) So
codes like

&timelocal(&normaldate($sec,$min,$hours,$mday - 7,$mon,$year));

is no good when you need to know "when a week ago was"; just call
timelocal() in such cases.

=head2 Epoch and range of dates

From version 2.0, newtimelocal is Epoch-independent; that is,
timelocal(0,0,0,1,0,70) is not guaranteed to return 0.  MacPerl, for
instance, uses 1904/01/01 as Epoch.

Unlike original timelocal.pl, MAXINT is set to 2**31 for any
environment except MacPerl so the "End of Date" is AD 2038.  daysgm()
is not bound for this limit.

Despite the fact that Epoch-independent coding was inspired by
Matthias Neeracher, the very author of MacPerl, gmtime(0) on MacPerl
returns a very funny value (as of 5.07r1m). MacPerl compatibility is
ad hoc and should be rewritten in future. 

=head1 AUTHOR

Dan Kogai (dankogai@dnsa.or.jp)

Epoch-independency inspired by Matthias Neeracher <neeri@iis.ee.ethz.ch>

The most recent version of newtimelocal.pl is always available via URL:

http://www.dnsa.or.jp/~dankogai/newtimelocal

=head1 HISTORY

=item 96/04/08 (version 2.0)

Compatible with MacPerl (As of 5.07r1m)

Epoch-independent

daysgm() now takes AD - 1900 as the value for year so a mere slice of
localtime() is acceptable (i.e.  &daysgm((localtime())[3..5]) to get
number of days since Epoch).

mktime() added; Just an alias of localtime().

=item 96/04/03 (version 1.0)

Algorithm was back to the previous, honest-to-goddess version. "H&T"
algorithm had some problem dealing with out-of-range values.

=item 96/04/02

Rewritten using the algorithm by Henry F. Fliegel and
Thomas C. van Flandern Henry F. Fliegel adn Thomas C. van Flandern
in the October 1968 in the October 1968 (vol 11 #10) issue of the 
Communications of the ACM.

Pod section added

=item 96/03

1st release

=cut
