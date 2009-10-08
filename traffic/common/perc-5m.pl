#
# $Id$
#

# Return the input and output $perc'th percentile of data
# for the given $dsp date-spec, for the (possible collection of)
# ports named in $name.  Also returns the number of days the data
# was computed over.

use strict;

require 'date.pl';
require 'read-5m-sum.pl';
require 'utils.pl';
require 'addup.pl';


sub get_percentile {
    my($dsp, $name, $perc) = @_;
    my($base_tm, $no_days) = &decode_datespec($dsp);
    my(@in, @out, @vars);
    my($in, $out);
    my($iov, $oov);
    our($max_sample, %sample_delta, %sample_time, %max_rate, %count);

    return undef unless $base_tm;

    foreach $d (0 .. $no_days - 1) {
	$tm = $base_tm + ($d) * (60*60*24);
	$date = &tm_to_date($tm);
	&read_5m_sum($name, $date);

	if (! defined $vars[0]) {
	    $iov = &octets_var("in");
	    $oov = &octets_var("out");

	    push(@vars, $iov, $oov);
	}

	&addup_values(\@vars, \@in, \@out,
	    $max_sample, \%count, \%sample_time);

	undef %count;
	undef %max_rate;
	undef $max_sample;
	undef %sample_delta;
	undef %sample_time;
    }

    my $in  = &percentile($perc, @in);
    my $out = &percentile($perc, @out);

    return ($in, $out, $no_days);
}

1;
