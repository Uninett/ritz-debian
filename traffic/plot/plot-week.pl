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
#	epoch for the entire epoch we have data for
#	mandatory parameter, no default
#   -n <name> 		name of "line", mandatory
#   -m <max-scale>	set max value on y scale (%) (default: autoscale)
#   -f <output-format>  may be one of
#	png
#       postscript (default)
#       x11 (not very useful, because the X window will disappear when
#            we exit, but we will pause 30 secs)
#       ppm
#       fig
#   -t <type-of-plot>	may be one of
#	traffic (percentage)
#	traffic-kbit
#	discards
#	errors
#	error-hrs
#   -r 			unconditionally regenerate plot
#


push(@INC, "%LIBDIR%");

require 'getopts.pl';
require 'date.pl';
require 'db-lookup.pl';
require 'search.pl';
require 'read-week-report.pl';
require 'scaling.pl';
require 'plot.pl';
require 'utils.pl';


sub plot_traffic_common {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($intf, $val);

    $intf = $line; 
    $ifspeed = $ifspeed{$intf, $d};

    if (defined($iftype{$intf, $d})) { # have data for date
	if (!defined($start_tm)) { # Record when we have first data
	    $start_tm = $tm;	# in global variables...
	    $start_day = $d;
	}
	# remember for later, when setting X tics
	$data_days = $d - $start_day + 1;

	printf($fh "%d ", ($d-$start_day)*24); # X-axis, hours

	&maxit($val = $peak_load_in{$intf, $d});
	printf($fh "%d ", $val);
	&maxit($val = $peak_load_out{$intf, $d});
	printf($fh "%d ", $val);
	&maxit($val = $busy_load_in{$intf, $d});
	printf($fh "%d ", $val);
	&maxit($val = $busy_load_out{$intf, $d});
	printf($fh "%d ", $val);
	&maxit($val = $average_load_in{$intf, $d});
	printf($fh "%d ", $val);
	&maxit($val = $average_load_out{$intf, $d});
	printf($fh "%d ", $val);
	printf($fh "\n");
    }
    
    undef(%busy_load_in);
    undef(%busy_load_out);
    undef(%peak_load_in);
    undef(%peak_load_out);
    undef(%average_load_in);
    undef(%average_load_out);
    undef(%ifspeed);
    undef(%iftype);
}

sub plot_traffic {
    my($line, $fh, $dn, $d, $tm) = @_;
    
    open(IN, $dn . "/traffic") || return undef;
    &read_traffic(IN, $d);
    close(IN);

    &plot_traffic_common($line, $fh, $dn, $d, $tm);
}

sub plot_traffic_kbit {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($intf, $val);
    
    open(IN, $dn . "/traffic.kbit") || return undef;
    &read_traffic_kbit(IN, $d);
    close(IN);

    &plot_traffic_common($line, $fh, $dn, $d, $tm);
}

sub kill_error_vars {

    undef(%errhrs_10);
    undef(%errhrs_01);
    undef(%errhrs_001);
    undef(%max_inerrs);
    undef(%avg_inerrs);
    undef(%max_ignores);
    undef(%avg_ignores);
    undef(%resets);
    undef(%max_resets);
    undef(%peak_discards);
    undef(%max_discards);
    undef(%avg_discards);
    undef(%iftype);
}

sub plot_errors_common {
    my($line, $fh, $dn, $d, $tm, $inner) = @_;
    my($intf, $val);
    
    open(IN, $dn . "/errors.perc") || return undef;
    &read_errors(IN, $d);
    close(IN);

    $intf = $line; 

    if (defined($iftype{$intf, $d})) { # have data for date
	if (!defined($start_tm)) { # Record when we have first data
	    $start_tm = $tm;	# in global variables...
	    $start_day = $d;
	}
	# remember for later, when setting X tics
	$data_days = $d - $start_day + 1;

	printf($fh "%d ", ($d-$start_day)*24); # X-axis, hours
	&$inner($intf, $d, $fh);
    }

    &kill_error_vars();
}

sub plot_discards_inner {
    my($intf, $d, $fh) = @_;
    my($val);

    &maxit($val = $peak_discards{$intf, $d});
    printf($fh "%s ", $val);
    &maxit($val = $max_discards{$intf, $d});
    printf($fh "%s ", $val);
    &maxit($val = $avg_discards{$intf, $d});
    printf($fh "%s ", $val);
    printf($fh "\n");
}

sub plot_discards {
    my($line, $fh, $dn, $d, $tm) = @_;    

    &plot_errors_common($line, $fh, $dn, $d, $tm,
			\&plot_discards_inner);
}

sub plot_error_hrs_inner {
    my($intf, $d, $fh) = @_;
    my($val);

    &maxit($val = $errhrs_10{$intf, $d});
    printf($fh "%s ", $val);
    &maxit($val = $errhrs_01{$intf, $d});
    printf($fh "%s ", $val);
    &maxit($val = $errhrs_001{$intf, $d});
    printf($fh "%s ", $val);
    printf($fh "\n");
}

sub plot_error_hrs {
    my($line, $fh, $dn, $d, $tm) = @_;

    &plot_errors_common($line, $fh, $dn, $d, $tm,
			\&plot_error_hrs_inner);
}

sub plot_errors_inner {
    my($intf, $d, $fh) = @_;
    my($val);

    &maxit($val = $max_inerrs{$intf, $d});
    printf($fh "%s ", $val);
    &maxit($val = $avg_inerrs{$intf, $d});
    printf($fh "%s ", $val);
    &maxit($val = $max_ignores{$intf, $d});
    printf($fh "%s ", $val);
    &maxit($val = $avg_ignores{$intf, $d});
    printf($fh "%s ", $val);
    printf($fh "\n");
}

sub plot_errors {
    my($line, $fh, $dn, $d, $tm) = @_;
    my($intf, $val);
    
    &plot_errors_common($line, $fh, $dn, $d, $tm,
			\&plot_errors_inner);
}

#
# "Decorate" plots, i.e. do the plots, set labels on axis etc.
#

sub decorate_traffic_1 {
    my($fh, $maxy, $df, $dsp, $ylabel) = @_;

    printf($fh
	   &plot_title(sprintf("%s weekly load %s, capacity %d kbit/s",
			       $name,
			       $dsp eq "epoch" ?
			         "for the epoch" :
			         sprintf("in %s",
					 &pretty_datespec($dsp)),
			       $ifspeed)
		       ));
					     
    printf($fh "%s", &plot_ylabel("$ylabel"));
    printf($fh &plot_xlabel("Time"));
    
    # Try to manage without this, (?)
    printf($fh &plot_yrange("0:$maxy"));
    
    # NB This should probably be generalized and put into plot.pl
    printf($fh "plot \"$df\" using 1:2 title \"peak-hr-in\" with lines,");
    printf($fh "     \"$df\" using 1:3 title \"peak-hr-out\" with lines,");
    printf($fh "     \"$df\" using 1:4 title \"busy-day-in\" with lines,");
    printf($fh "     \"$df\" using 1:5 title \"busy-day-out\" with lines,");
    printf($fh "     \"$df\" using 1:6 title \"average-in\" with lines,");
    printf($fh "     \"$df\" using 1:7 title \"average-out\" with lines\n");
}

sub decorate_traffic {
    my($fh, $maxy, $df, $dsp) = @_;

    &decorate_traffic_1($fh, $maxy, $df, $dsp, "% load");
}

sub decorate_traffic_kbit {
    my($fh, $maxy, $df, $dsp) = @_;

    &decorate_traffic_1($fh, $maxy, $df, $dsp, "kbit/s");
}

sub decorate_discards {
    my($fh, $maxy, $df, $dsp) = @_;
    
    printf($fh
	   &plot_title(sprintf("%s weekly output discard rate, %s",
			       $name, &pretty_datespec($dsp))));
    
    printf($fh "%s", &plot_ylabel("% discards"));
    printf($fh &plot_xlabel("Time"));
    printf($fh &plot_yrange("0:$maxy"));

    printf($fh "plot \"$df\" using 1:2 title \"peak-hr\" with lines,");
    printf($fh "     \"$df\" using 1:3 title \"max-day\" with lines,");
    printf($fh "     \"$df\" using 1:4 title \"week-avg\" with lines\n");
}

sub decorate_error_hrs {
    my($fh, $maxy, $df, $dsp) = @_;

    printf($fh
	   &plot_title(sprintf("%s weekly input error hours, %s",
			       $name, &pretty_datespec($dsp))));
    printf($fh "%s", &plot_ylabel("hours with error rate above threshold"));
    printf($fh &plot_xlabel("Time"));
    printf($fh &plot_yrange("0:$maxy"));

    printf($fh "plot \"$df\" using 1:2 title \"thresh=1.0%%\" with lines,");
    printf($fh "     \"$df\" using 1:3 title \"thresh=0.1%%\" with lines,");
    printf($fh "     \"$df\" using 1:4 title \"thresh=.01%%\" with lines\n");
}

sub decorate_errors {
    my($fh, $maxy, $df, $dsp) = @_;

    printf($fh
	   &plot_title(sprintf("%s weekly input errors / ignores, %s",
			       $name, &pretty_datespec($dsp))));
    printf($fh "%s", &plot_ylabel("% input error / input ignores"));
    printf($fh &plot_xlabel("Time"));
    printf($fh &plot_yrange("0:$maxy"));

    printf($fh "plot \"$df\" using 1:2 title \"max-day-ierrs\" with lines,");
    printf($fh "     \"$df\" using 1:3 title \"avg-ierrs\" with lines,");
    printf($fh "     \"$df\" using 1:4 title \"max-day-ignores\" with lines,");
    printf($fh "     \"$df\" using 1:5 title \"avg-ignores\" with lines\n");
}

#
#
#

%data_plotter = (
		 "traffic"	=> \&plot_traffic,
	         "traffic-kbit"	=> \&plot_traffic_kbit,
	         "discards"	=> \&plot_discards,
	         "error-hrs"	=> \&plot_error_hrs,
	         "errors"	=> \&plot_errors
		 );

%decorator = (
	      "traffic"		=> \&decorate_traffic,
	      "traffic-kbit"	=> \&decorate_traffic_kbit,
	      "discards"	=> \&decorate_discards,
	      "error-hrs"	=> \&decorate_error_hrs,
	      "errors"		=> \&decorate_errors,
	      );

#
#
#

sub make_plot_file  {
    my($line, $datespec, $device, $plot) = @_;
    my($val, $maxy);
    my($w, $last_w, $y, $save_tm);
    my($di_plotname, $plotit, $decorate, $regen, $dsp);

    # Look up filenames for plot-files for the given line, date and
    # output device.
    ($refname, $plotname, $plotdatafile, $di_plotname) = 
	&plot_names("week-" . $plot, $line, $datespec, $device);

    ($base_tm, $no_days) = &decode_datespec($datespec);
    return undef unless $base_tm;

    # Check to see if we really need to generate a new plotdata file.
    # Here we have a potential for more intelligence. If we find a
    # plot file for a time period which covers the date we are looking
    # for, we could find our plot data from this, by extracting the
    # lines corresponding to the timeperiod we are looking for

    # This has now been even more simplified...

    $regen = 0;

    if (defined($opt_r) ||
	! -r $plotdatafile ||
	# the data file was produced within the datespec
	(&tm_in_datespec(&modtime($plotdatafile), $datespec) &&
	 # and we have a new week?
	 (! &same_week(&modtime($plotdatafile), time))))
    {
	$regen = 1;
	open (PLOTDATA, ">$plotdatafile");
	$tm = $base_tm;

	foreach $d (0 .. $no_days - 1) {
	    ($w, $y) = &tm_to_week_and_year($tm);
	    $save_tm = $tm;
	    $tm = $base_tm + ($d+1) * (60*60*24);

	    if (!defined($last_w) ||
		$w != $last_w)
	    {
		$last_w = $w;

		$dsp = &make_datespec("week", $y . "-" . $w);
		$dn = &find_week_report_dir($dsp);
		if (!defined($dn)) { next; } # oops...
		if (!defined($plotit = $data_plotter{$plot})) {
		    die "Could not find data plotter routine for $plot\n";
		}
		&$plotit($line, PLOTDATA, $dn, $d, $save_tm);
	    }
	}

	close(PLOTDATA);
    }

    if (defined($opt_m)) {
	$maxy = $opt_m;
    } else {
	$maxy = &max_scale();	# Autoscale
    }
    
    # Now prepare the plot command files for gnuplot
    if (! -r $di_plotname || $regen) {
	open(DIP, ">$di_plotname");

	printf(DIP &plot_set_xtics($start_tm, $data_days, $data_days));

	if (!defined($decorate = $decorator{$plot})) {
	    die "Could not find decorator for $plot\n";
	}
	&$decorate(DIP, $maxy, $plotdatafile, $datespec);
	close(DIP);
    }

    if (! -r $plotname) {

	open(PLOT, ">$plotname");
#   select(plot); $| = 1;
	
	printf(PLOT &plot_init($device));
	printf(PLOT "load \"%s\"\n", $di_plotname);
	printf(PLOT &plot_exit($device));
	close(PLOT);
    }

    return("$plotname");
}


#
# Main
#

&Getopts("f:n:d:m:rt:");

$name = $opt_n;
$datespec = $opt_d;
$format = $opt_f;
$plot = $opt_t;

if (!defined($format)) { $format = "postscript"; }
if (!defined($name)) { die "You have to specify the port name\n"; }
if (!defined($plot)) { $plot = "traffic"; }
if (!defined($datespec)) {
    die "You have to specify the datespec covering the period to plot\n";
}

umask(0);

$plotname = &make_plot_file($name, $datespec, $format, $plot);

if ($plotname) {
    system("%GNUPLOT% $plotname");
}
