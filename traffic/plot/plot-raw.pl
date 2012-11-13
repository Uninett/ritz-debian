#!%PERL%
#
# $Id$
#

# Copyright (c) 1996, 1997
#      UNINETT and NORDUnet.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgement:
#      This product includes software developed by UNINETT and NORDUnet.
# 4. Neither the name of UNINETT or NORDUnet nor the names
#    of its contributors may be used to endorse or promote
#    products derived from this software without specific prior
#    written permission.
#
# THIS SOFTWARE IS PROVIDED BY UNINETT AND NORDUnet ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL UNINETT OR NORDUnet OR
# THEIR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Produces a plot (of specified data type) on stdout (except for X11)
# Options:
#   -d <datespec>
#       yyyy-mm for a month
#       yyyy--ww for a week
#       yyyy-mm--dd for a day
#       yyyy-mm-dd for a day
#       (default is yesterday)
#   -n <name> 		name of logical port, mandatory
#   -m <max-scale>	set max value on y scale (%) (default: autoscale)
#   -f <output-format>  may be one of
#	png
#       postscript (default)
#       x11 (not very useful, because the X window will disappear when
#            we exit, but we will pause 30 secs)
#       ppm
#       fig
#   -t <type-of-plot>	may be one of
#	traffic		(percentage, default)
#	traffic-kbit
#	discards
#	errors
#	resets
#	eerrs
#	pps
#	mpps
#	upps
#	ip6perc
#   -r 			unconditionally regenerate plot
#

push(@INC, "%LIBDIR%");

use Getopt::Std;

require 'date.pl';
require 'db-lookup.pl';
require 'search.pl';
require 'read-raw-log.pl';
require 'scaling.pl';
require 'plot.pl';
require 'utils.pl';


sub plot_traffic_common {
    my($line, $fh, $dn, $d, $tm, $compute_val) = @_;
    my($i, $h, $val, $v, %then, $now, %add);
    my($started) = 0;
    my(@vars);
    our($ifspeed);

    $vars[0] = &octets_var("in");
    $vars[1] = &octets_var("out");
    
    foreach $v (@vars) {
	$add{$v} = 0;
    }

    foreach $i (0 .. $max_sample) {
	if ($i == 0) {
	    foreach $v (@vars) {
		$then{$v} = $sample_time{$v,0};
	    }
	    next;
	}
	if (!$started) {
	    if ($sample_time{$vars[0],$i} > 23) {
		next;
	    }
	}
	$started = 1;

	my($in, $out);
	undef $in;
	undef $out;

	foreach $v (@vars) {
	    $now = $sample_time{$i};
	    $time_delta = 3600.0 * ($now - $then{$v});
	    if ($time_delta < 0) { # Ignore samples before midnight the 
		$add{$v} = 0;	# "previous" day (not sure this comes out
		$then{$v} = $now; # exactly right...
	    } elsif ($time_delta <= 30) { # Skip samples w. too small interval
		$add{$v} += $count{$v,$i}; # But add data
	    } else {
		$then{$v} = $now;
		$val = &$compute_val($count{$v,$i} + $add{$v},
				     $time_delta);
		if ($v =~ /Octets/ && $ifspeed != 0) {
		    if ($val * 1000.0 > $ifspeed * 1.05) { # Allow 5% overshoot
			$val = 0;
		    }
		}

		&maxit($val);
		$add{$v} = 0;
		if ($v =~ /In/) {
		    $in = $val;
		} else {
		    $out = $val;
		}
	    }
	}
	if (defined($in) && defined($out)) {
	    printf($fh " %f", $sample_time{$i} + ($d*24));
	    printf($fh " %f %f\n", $in, $out);
	}
    }
}

sub plot_traffic_inner {
    my($octets, $dt) = @_;

    return($octets*8 * 100.0/$dt/$ifspeed);
}

sub plot_traffic {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($i, $h, $val, $v, %then, $now, %add);
    
    &plot_traffic_common($line, $fh, $dn, $d, $tm,
			 \&plot_traffic_inner);
}

sub decorate_traffic_1 {
    my($fh, $maxy, $df, $dsp, $ylabel) = @_;
    my($scale, $label);

    printf($fh
	   &plot_title(sprintf("%s load (samples) on %s, capacity %s",
			       $name,
			       &pretty_datespec($dsp),
			       &pretty_ifspeed($ifspeed))));
    printf($fh &plot_xlabel("Time"));

    # scale real data rates to appropriate decimal unit
    if ($ylabel eq "kbit/s") {
	($scale, $label) = &scale_kbit_values($maxy);
	$ylabel = $label;	# override with scaled unit
    } else {
	$scale = 1.0;
    } 

    printf($fh "%s", &plot_ylabel($label));

    # Try to manage without this (?)
    printf($fh &plot_yrange(
	       sprintf("0:%s", $maxy / $scale)));
    
    # NB This should be generalized and put into plot.pl
    printf($fh "plot  \"$df\" using 1:(\$2/$scale) title \"in\" with lines,");
    printf($fh "      \"$df\" using 1:(\$3/$scale) title \"out\" with lines\n");
}

sub decorate_traffic {
    my($fh, $maxy, $df, $dsp) = @_;

    &decorate_traffic_1($fh, $maxy, $df, $dsp, "% load");
}

sub plot_traffic_kbit_inner {
    my($octets, $dt) = @_;

    return($octets*8 / $dt / 1000);
}

sub plot_traffic_kbit {
    my($line, $fh, $dn, $d, $tm) = @_;
    
    &plot_traffic_common($line, $fh, $dh, $d, $tm,
			 \&plot_traffic_kbit_inner);
}

sub decorate_traffic_kbit {
    my($fh, $maxy, $df, $dsp) = @_;

    &decorate_traffic_1($fh, $maxy, $df, $dsp, "kbit/s");
}

sub plot_discards {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($i, $has_ignores, $val, $pkts);

    $has_ignores = defined($base{"locIfInIgnored"});
    foreach $i (0 .. $max_sample) {
	printf($fh "%f", $sample_time{$i} + ($d*24));

	$pkts = ($count{"ifOutUcastPkts",$i} +
		 $count{"ifOutNUcastPkts",$i} +
		 $count{"ifOutDiscards",$i});
	if ($pkts > 0) {
	    &maxit($val = $count{"ifOutDiscards",$i} * 100.0 / $pkts);
	} else {
	    $val = 0;
	}
	printf($fh " %f", $val);

	if ($has_ignores) {
	    $pkts = ($count{"ifInUcastPkts",$i} +
		     $count{"ifInNUcastPkts",$i} +
		     $count{"ifInErrors",$i} +
		     $count{"locIfInIgnored",$i});
	    if ($pkts > 0) {
		&maxit($val = $count{"locIfInIgnored",$i} * 100.0 / $pkts);
	    } else {
		$val = 0;
	    }
	    printf ($fh " %f", $val);
	} else {
	    printf($fh " 0");
	}
	printf($fh "\n");
    }
}

sub decorate_discards {
    my($fh, $maxy, $df, $dsp) = @_;

    printf($fh
	   &plot_title(sprintf("%s %s (samples) on %s",
			       $name,
			       "out-discards / in-ignores",
			       &pretty_datespec($dsp))));
    printf($fh &plot_xlabel("Time"));
    printf($fh "%s", &plot_ylabel("% discards / ignores"));

    # Try to manage without this (?)
    printf($fh &plot_yrange("0:$maxy"));
    
    # NB This should be generalized and put into plot.pl
    printf($fh "plot  \"$df\" using 1:2 title \"discards\" with lines,");
    printf($fh "      \"$df\" using 1:3 title \"ignores\" with lines\n");
}

sub plot_errors {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($i, $has_details, $val, $pkts, $v, $tprinted);

    $has_details = defined($base{"locIfInCRC"});

    foreach $i (0 .. $max_sample) {
	$tprinted = 0;
	printf($fh "%f", $sample_time{$i} + ($d * 24));

	$pkts = ($count{"ifInUcastPkts",$i} +
		 $count{"ifInNUcastPkts",$i} +
		 $count{"ifInErrors",$i});
	if ($pkts > 0) {
	    &maxit($val = $count{"ifInErrors",$i} * 100.0 / $pkts);
	} else {
	    $val = 0;
	}
	printf ($fh " %f", $val);

	if ($has_details) {
	    if ($pkts > 0) {
		&maxit($val = $count{"locIfInCRC",$i} * 100.0 / $pkts);
		printf($fh " %f", $val);
		&maxit($val = $count{"locIfInFrame",$i} * 100.0 / $pkts);
		printf($fh " %f", $val);
		&maxit($val = $count{"locIfInAbort",$i} * 100.0 / $pkts);
		printf($fh " %f", $val);
	    } else {
		printf($fh " 0 0 0"); 
	    }
	} else {
	    printf($fh " 0 0 0");
	}
	printf($fh "\n");
    }
}

sub decorate_errors {
    my($fh, $maxy, $df, $dsp) = @_;

    printf($fh
	   &plot_title(sprintf("%s %s (samples) on %s",
			       $name,
			       "input errors",
			       &pretty_datespec($dsp))));
    printf($fh &plot_xlabel("Time"));
    printf($fh "%s", &plot_ylabel("% input errors"));

    # Try to manage without this (?)
    printf($fh &plot_yrange("0:$maxy"));
    
    # NB This should be generalized and put into plot.pl
    printf($fh "plot  \"$df\" using 1:2 title \"Errs\" with lines,");
    printf($fh "      \"$df\" using 1:3 title \"CRC\" with lines,");
    printf($fh "      \"$df\" using 1:4 title \"Frame\" with lines,");
    printf($fh "      \"$df\" using 1:5 title \"Abort\" with lines\n");
}

sub plot_pps_common {
    my($fh, $d, $ivr, $ovr) = @_;
    my($i, $val, $inpkts, $outpkts, $inpps, $outpps, $dt);
    
    foreach $i (0 .. $max_sample) {
	if ($i == 0) { next; }
	printf($fh "%f", $sample_time{$i} + ($d * 24));
	$outpkts = $inpkts = 0;
	foreach my $v (@{$ivr}) {
	    $inpkts += $count{$v,$i};
	}
	foreach my $v (@{$ovr}) {
	    $outpkts += $count{$v,$i};
	}
	$dt = ($sample_time{$i} - $sample_time{$i-1}) * 3600;
	$inpps = $inpkts / $dt;
	$outpps= $outpkts / $dt;
	&maxit($inpps);
	&maxit($outpps);
	printf($fh " %d %d\n", $inpps, $outpps);
    }
}

sub has_multicast_pkts {
    our(%count);

    return (defined($count{"ifInMulticastPkts",0}));
}

sub plot_mpps {
    my($line, $fh, $dn, $d, $tm) = @_;

    if (&has_multicast_pkts()) {
	&plot_pps_common($fh, $d,
			 ["ifInMulticastPkts"],
			 ["ifOutMulticastPkts"]);
    } else {
	&plot_pps_common($fh, $d,
			 ["ifInNUcastPkts"],
			 ["ifOutNUcastPkts"]);
    }
}

sub plot_upps {
    my($line, $fh, $dn, $d, $tm) = @_;
    
    &plot_pps_common($fh, $d,
		     ["ifInUcastPkts"],
		     ["ifOutUcastPkts"]);
}

sub plot_pps {
    my($line, $fh, $dn, $d, $tm) = @_;

    if (&has_multicast_pkts()) {
	&plot_pps_common($fh, $d,
			 ["ifInUcastPkts",
			  "ifInMulticastPkts",
			  "ifInBroadcastPkts"],
			 ["ifOutUcastPkts",
			  "ifOutMulticastPkts",
			  "ifOutBroadcastPkts"]);
    } else {
	&plot_pps_common($fh, $d,
			 ["ifInUcastPkts", "ifInNUcastPkts"],
			 ["ifOutUcastPkts", "ifOutNUcastPkts"]);
    }
}

sub decorate_pps_common {
    my($fh, $maxy, $df, $dsp, $title) = @_;

    printf($fh
	   &plot_title(sprintf("%s %s (samples) on %s",
			       $name,
			       $title,
			       &pretty_datespec($dsp))));
    printf($fh &plot_xlabel("Time"));
    printf($fh "%s", &plot_ylabel("pps"));

    # Try to manage without this (?)
    printf($fh &plot_yrange("0:$maxy"));
    
    # NB This should be generalized and put into plot.pl
    printf($fh "plot  \"$df\" using 1:2 title \"input\" with lines,");
    printf($fh "      \"$df\" using 1:3 title \"output\" with lines\n");
}

sub decorate_pps {
    my($fh, $maxy, $df, $dsp) = @_;

    &decorate_pps_common($fh, $maxy, $df, $dsp, "packets per second");
}

sub decorate_upps {
    my($fh, $maxy, $df, $dsp) = @_;

    &decorate_pps_common($fh, $maxy, $df, $dsp, "unicast packets per second");
}

sub decorate_mpps {
    my($fh, $maxy, $df, $dsp) = @_;

    &decorate_pps_common($fh, $maxy, $df, $dsp, "multicast packets per second");
}

sub plot_ip6perc {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($i, $val);
    our($max_sample);
    my($iperc, $operc);
    
    foreach $i (0 .. $max_sample) {
	my($ipkts, $opkts, $i6pkts, $o6pkts);

	if (&has_multicast_pkts()) {
	    $ipkts =
		$count{"ifInUcastPkts",$i} +
		$count{"ifInMulticastPkts",$i} +
		$count{"ifInBroadcastPkts",$i};
	    $opkts =
		$count{"ifOutUcastPkts",$i} +
		$count{"ifOutMulticastPkts",$i} +
		$count{"ifOutBroadcastPkts",$i};
	} else {
	    $ipkts =
		$count{"ifInUcastPkts",$i} +
		$count{"ifInNUcastPkts",$i};
	    $opkts =
		$count{"ifOutUcastPkts",$i} +
		$count{"ifOutNUcastPkts",$i};
	}
	$i6pkts = $count{"ipv6IfStatsInReceives",$i};
	$o6pkts = $count{"ipv6IfStatsOutForwDatagrams",$i};

	if ($ipkts != 0) {
	    $iperc = $i6pkts * 100.0 / $ipkts;
	} else {
	    $iperc = 0;
	}
	if ($opkts != 0) {
	    $operc = $o6pkts * 100.0 / $opkts;
	} else {
	    $operc = 0;
	}
	&maxit($iperc);
	&maxit($operc);
	printf($fh "%f %f %f\n",
	       $sample_time{$i} + ($d * 24),
	       $iperc, $operc);
    }
}

sub decorate_ip6perc {
    my($fh, $maxy, $df, $dsp) = @_;

    printf($fh "%s",
	   &plot_title(sprintf("%s IPv6 %% pkts (samples) on %s",
			       $name, &pretty_datespec($dsp))));
    printf($fh &plot_xlabel("Time"));
    printf($fh &plot_ylabel("% IPv6"));

    printf($fh &plot_yrange("0:$maxy"));

    printf($fh "plot  \"$df\" using 1:2 title \"IPv6%% in\" with lines,");
    printf($fh "      \"$df\" using 1:3 title \"IPv6%% out\" with lines\n");
}
    
sub plot_resets {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($i, $val);

    foreach $i (0 .. $max_sample) {
	printf($fh "%f", $sample_time{$i} + ($d*24));
	&maxit($val = $count{"locIfResets", $i});
	printf($fh " %f\n", $val);
    }
}

sub decorate_resets {
    my($fh, $maxy, $df, $dsp) = @_;

    printf($fh
	   &plot_title(sprintf("%s %s (samples) on %s",
			       $name,
			       "resets",
			       &pretty_datespec($dsp))));
    printf($fh &plot_xlabel("Time"));
    printf($fh "%s", &plot_ylabel("resets"));

    # Try to manage without this (?)
    printf($fh &plot_yrange("0:$maxy"));
    
    # NB This should be generalized and put into plot.pl
    printf($fh "plot  \"$df\" using 1:2 title \"Resets\" with lines\n");
}

sub plot_eerrs {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($i, $ipkts, $opkts, $has_details);

    $has_details = defined($base{"locIfInCRC"});

    foreach $i (0 .. $max_sample) {
	printf($fh "%f", $sample_time{$i} + ($d*24));

	$ipkts = ($count{"ifInUcastPkts",$i} +
		  $count{"ifInNUcastPkts",$i} +
		  $count{"ifInErrors",$i});
	$opkts = ($count{"ifOutUcastPkts",$i} +
		  $count{"ifOutNUcastPkts",$i} +
		  $count{"ifOutErrors",$i});
	
	if ($ipkts > 0) {
	    &maxit($val = $count{"ifInErrors",$i} * 100.0 / $ipkts);
	} else {
	    $val = 0;
	}
	printf ($fh " %f", $val);
	    
	if ($opkts > 0) {
	    &maxit($val = $count{"ifOutErrors",$h} * 100.0 / $opkts);
	} else {
	    $val = 0;
	}
	printf ($fh " %f", $val);

	if ($has_details) {
	    if ($ipkts > 0) {
		&maxit($val = $count{"locIfInCRC",$i}
		       * 100.0 / $ipkts);
		printf($fh " %f", $val);
		&maxit($val = $count{"locIfInFrame",$i}
		       * 100.0 / $ipkts);
		printf($fh " %f", $val);
		&maxit($val = $count{"locIfInRunts",$i}
		       * 100.0 / $ipkts);
		printf($fh " %f", $val);
		&maxit($val = $count{"locIfInGiants",$i}
		       * 100.0 / $ipkts);
		printf($fh " %f", $val);
	    } else {
		printf($fh " 0 0 0 0");
	    }
	} else {
	    printf($fh " 0 0 0 0");
	}
	printf($fh "\n");
    }
}

sub decorate_eerrs {
    my($fh, $maxy, $df, $dsp) = @_;

    printf($fh
	   &plot_title(sprintf("%s %s (samples) on %s",
			       $name,
			       "ether errors",
			       &pretty_datespec($dsp))));
    printf($fh &plot_xlabel("Time"));
    printf($fh "%s", &plot_ylabel("% errors"));

    # Try to manage without this (?)
    printf($fh &plot_yrange("0:$maxy"));
    
    # NB This should be generalized and put into plot.pl
    printf($fh "plot  \"$df\" using 1:2 title \"In-errs\" with lines,");
    printf($fh "      \"$df\" using 1:3 title \"Out-errs\" with lines,");
    printf($fh "      \"$df\" using 1:4 title \"CRC\" with lines,");
    printf($fh "      \"$df\" using 1:5 title \"Frame\" with lines,");
    printf($fh "      \"$df\" using 1:6 title \"Runts\" with lines,");
    printf($fh "      \"$df\" using 1:7 title \"Giants\" with lines\n");
}

#
#
#

%data_plotter = (
    "traffic"		=> \&plot_traffic,
    "traffic-kbit"	=> \&plot_traffic_kbit,
    "discards"		=> \&plot_discards,
    "errors"		=> \&plot_errors,
    "resets"		=> \&plot_resets,
    "eerrs"		=> \&plot_eerrs,
    "pps"		=> \&plot_pps,
    "upps"		=> \&plot_upps,
    "mpps"		=> \&plot_mpps,
    "ip6perc"		=> \&plot_ip6perc,
    );

%decorator = (
    "traffic"		=> \&decorate_traffic,
    "traffic-kbit"	=> \&decorate_traffic_kbit,
    "discards"		=> \&decorate_discards,
    "errors"		=> \&decorate_errors,
    "resets"		=> \&decorate_resets,
    "eerrs"		=> \&decorate_eerrs,
    "pps"		=> \&decorate_pps,
    "upps"		=> \&decorate_upps,
    "mpps"		=> \&decorate_mpps,
    "ip6perc"		=> \&decorate_ip6perc,
    );

#
#
#

sub make_plot_file  {
    my($line, $datespec, $device, $plot) = @_;
    my($plotf);
    my($h, $val, $maxy);
    my($houroffset);
    my($save_tm);
    my($di_plotname, $plotit, $decorate, $regen);

    # Look up filenames for plot-files for the given line, date and
    # output device.
    ($refname, $plotname, $plotdatafile, $di_plotname) = 
	&plot_names("raw-" . $plot, $line, $datespec, $device);

    ($base_tm, $no_days) = &decode_datespec($datespec);
    return undef unless $base_tm;

    $regen = 0;

    if (defined($opt_r) ||
	! -r $plotdatafile ||
	# the data file was produced within the datespec
	(&tm_in_datespec(&modtime($plotdatafile), $datespec) &&
	 (
	  # ...and we have a new day
	  (! &same_day(&modtime($plotdatafile), time)) ||
	  # ...or we're plotting "today"
	  (&is_today($datespec)))))
    {
	$regen = 1;

	open(PLOTDATA, ">$plotdatafile") ||
	    die "Could not open $plotdatafile for write: $!\n";

	$tm = $base_tm;
	foreach $d (0 .. $no_days - 1) {
	    $tm = $base_tm + ($d) * (60*60*24);
	    $date = &tm_to_date($tm);

	    if (! defined($base = &name_to_file($line, $date))) {
		&plot_err("Could not find base file name for $line / $date\n");
		next;
	    }
	    ($catter, $f) = &find_cat_and_file($base, $date);
	    if (! defined($f)) {
		&plot_err("Could not find data file for $base / $date\n");
		next;
	    }
	    open(DAYLOG, "$catter $f |") ||
		die "Could not open \"$catter $f\": $!\n";
	    &read_log(DAYLOG, $tm);
	    close(DAYLOG);	

	    if (!defined($start_tm)) { # Record when we have first data
		$start_tm = $tm; # in global variables...
		$start_day = $d;
	    }

	    # remember for later, when setting X tics
	    $data_days = $d - $start_day + 1;
	    
	    if (!defined($plotit = $data_plotter{$plot})) {
		die "Could not find data plotter routine for $plot\n";
	    }
	    &$plotit($line, PLOTDATA, $dn, $d, $save_tm);

	    undef(%count);
	    undef(%max_rate);
	}
	close (PLOTDATA);
    }

    if (defined($opt_m)) {
	$maxy = $opt_m;
    } else {
	$maxy = &max_scale();	# Autoscale
    }
    
    # Now prepare the plot command files for gnuplot
    if (! -r $di_plotname || $regen) {
	open(DIP, ">$di_plotname") ||
	    die "Could not open $di_plotname for write: $!\n";

	printf(DIP &plot_set_xtics($base_tm, $data_days, $no_days));

	if (!defined($decorate = $decorator{$plot})) {
	    die "Could not find decorator for $plot\n";
	}
	&$decorate(DIP, $maxy, $plotdatafile, $datespec);
	close(DIP);
    }

    if (! -r $plotname) {
	open(PLOT, ">$plotname") ||
	    die "Could not open $plotname for write: $!\n";
#	select (plot); $| = 1;
	printf(PLOT &plot_init($device));
	printf(PLOT "load \"%s\"\n", $di_plotname);
	printf(PLOT &plot_exit($device));
	close(PLOT);
    }

    return($plotname);
}


#
# Main
#

&getopts("f:d:m:n:rt:");

$name = $opt_n;
$datespec = $opt_d;
$format = $opt_f;
$plot = $opt_t;

if (!defined($format)) { $format = "postscript"; }
if (!defined($name)) { die "You have to specify the port name\n"; }
if (!defined($plot)) { $plot = "traffic"; }
if (!defined($datespec)) { $datespec = &yesterday_spec(); }

umask(0);

$plotname = &make_plot_file($name, $datespec, $format, $plot);

if ($plotname) {
    system("%GNUPLOT% $plotname");
}
