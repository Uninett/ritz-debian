#
# $Id$
#

#
# Add up 'in' and 'out' values in a hash given as input.
#
# $vref is a ref to a list of variables to process, those
#    matching /In/ are added as input, the others as output
#    (typically used for ifInOctets / ifHCInOctets etc.)
# Results are in $iref and $oref (refs to arrays), for
#    input and output values, respectively.
# $max_sample is the max number of samples in the inputs
# $sample_ref is a ref to the hash for the samples
# $stime_ref is a ref to the hash for the times for the sample,
#    relative to 00:00 in hours
#

sub addup_values {
    my($vref, $iref, $oref, $max_sample, $sample_ref, $stime_ref) = @_;
    my($in, $out, $started);
    my(%then, %add);
    
    foreach $i (0 .. $max_sample) {
	if ($i == 0) {
	    foreach $v (@{$vref}) {
		$then{$v} = ${$stime_ref}{$v,0};
	    }
	    next;
	}
	if (!$started) {
	    if (${$stime_ref}{$vars[0],$i} > 23) {
		next;
	    }
	}
	$started = 1;

	undef $in;
	undef $out;

	foreach $v (@{$vref}) {
	    $now = ${$stime_ref}{$v,$i};
	    $time_delta = 3600.0 * ($now - $then{$v});
	    if ($time_delta < 0) { # Ignore samples before midnight the 
		$add{$v} = 0;	# "previous" day (not sure this comes out
		$then{$v} = $now; # exactly right...
	    } elsif ($time_delta <= 30) { # Skip samples w. too small interval
		$add{$v} += ${$sample_ref}{$v,$i}; # But add data
	    } else {
		$then{$v} = $now;
		# Specialized for kbit/s computation
		$val = (${$sample_ref}{$v,$i} + $add{$v})
		    * 8.0/1000 / $time_delta;
		$add{$v} = 0;
		if ($v =~ /In/) {
		    $in = $val;
		} else {
		    $out = $val;
		}
	    }
	}
	if (defined($in) && defined($out)) {
	    push(@{$iref}, $in);
	    push(@{$oref}, $out);
#	    printf("in %s out %s\n", $in, $out);
	}
    }
}

1;
