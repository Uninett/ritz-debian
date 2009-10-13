#
# $Id$
#

# Return the input and output $perc'th percentile of data
# volume for the given $dsp date-spec, for the logical port
# named in $name.  Also returns number of days the data was
# computed over.


use strict;

require 'date.pl';
require 'search.pl';
require 'db-lookup.pl';
require 'read-raw-log.pl';
require 'utils.pl';
require 'addup.pl';


sub find_file {
    my($base_tm, $day, $name) = @_;

    my $tm = $base_tm + $day * (60*60*24);
    my $date = &tm_to_date($tm);
    my $base = &name_to_file($name, $date);
    if (!defined $base) {
	die "Could not find base file name for $name / $date\n";
    }
    my($cat, $f) = &find_cat_and_file($base, $date);
    if (!defined $f) {
	die "Could not find data file for $base / $date\n";
    }
    return "$cat $f |";
}

sub get_percentile {
    my($dsp, $name, $perc) = @_;
    my($base_tm, $no_days) = &decode_datespec($dsp);
    my(@in, @out, @vars);
    my($in, $out);
    my($iov, $oov);
    my($tm);
    our($max_sample, %sample_delta, %sample_time, %max_rate, %count);
    my($FH);

    return undef unless $base_tm;

    foreach my $d (0 .. $no_days - 1) {
	$tm = $base_tm + $d * 24 * 3600;
	open($FH, &find_file($base_tm, $d, $name));
	&read_log($FH, $tm);
	close($FH);

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
