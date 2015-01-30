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

#
# cgi-bin script to produce plot of hourly average & peak load for a
# given date specification
#

#use strict;

push(@INC, "%LIBDIR%");

$docbase = "%HTMLDIR%";

use CGI;

require 'date.pl';
require 'search.pl';
require 'db-lookup.pl';
require 'utils.pl';
require 'plot.pl';


%plot_title = (
    "traffic",		"traffic in percent of capacity",
    "traffic-kbit",	"traffic in kbit/s",
    "discards",		"output discards / input ignores",
    "errors",		"input errors",
    "resets",		"interface resets",
    "eerrs",		"ethernet errors",
    "error-hrs",	"error hours above thresholds",
    "pps",		"packets per second",
    "mpps",		"multicast packets per second",
    "upps",		"unicast packets per second",
    "ip6perc",		"percent of IPv6 packets",
    );

%resolution_plots = (
		     "raw" => {
			 "traffic" => 1,
			 "traffic-kbit" => 1,
			 "discards" => 1,
			 "errors" => 1,
			 "resets" => 1,
			 "eerrs" => 1,
			 "pps" => 1,
			 "mpps" => 1,
			 "upps" => 1,
			 "ip6perc" => 1,
		     },
		     "5m" => {
			 "traffic" => 1,
			 "traffic-kbit" => 1,
			 "discards" => 1,
			 "errors" => 1,
			 "resets" => 1,
			 "eerrs" => 1,
			 "pps" => 1,
			 "mpps" => 1,
			 "upps" => 1,
			 "ip6perc" => 1,
		     },
		     "hr" => {
			 "traffic" => 1,
			 "traffic-kbit" => 1,
			 "discards" => 1,
			 "errors" => 1,
			 "resets" => 1,
			 "eerrs" => 1,
			 "pps" => 1,
			 "mpps" => 1,
			 "upps" => 1,
			 "ip6perc" => 1,
		     },
		     "day" => {
			 "traffic" => 1,
			 "traffic-kbit" => 1,
			 "discards" => 1,
			 "errors" => 1,
			 "error-hrs" => 1,
		     },
		     "week" => {
			 "traffic" => 1,
			 "traffic-kbit" => 1,
			 "discards" => 1,
			 "errors" => 1,
			 "error-hrs" => 1,
		     },
		     );


%resolution_name = (
		    "raw" => "samples",
		    "5m" => "5-min averages",
		    "hr"  => "hourly",
		    "day" => "daily",
		    "week"=> "weekly",
		    );

# (resolution,period) => pairs of (resolution,period)

%zoom_out = (
	     "raw" => {
		 "day" => 	["hr", "day",
				 "hr", "week",
				 "day", "month"],
		 "week" =>	["day", "month"],
		 "month" =>	["day", "year",
				 "week", "epoch"],
	     },
	     "5m" => {
		 "day" =>	["5m", "week",
				 "hr", "week",
				 "day", "month"],
		 "week" =>	["day", "month"],
		 "month" =>	["day", "year",
				 "week", "year",
				 "week", "epoch"],
	     },
	     "hr" => {
		 "day" =>	["hr", "week"],
		 "week" =>	["day", "month"],
		 "month" =>	["day", "year",
				 "week", "year",
				 "week", "epoch"],
	     },
	     "day" => {
		 "week" =>	["day", "month",
				 "week", "year",
				 "week", "epoch"],
		 "month" =>	["week", "year",
				 "week", "epoch"],
		 "year" =>	["week", "year",
				 "week", "epoch"],
		 "epoch" =>	["week", "epoch"],
	     },
	     "week" => {
		 "year" =>	["week", "epoch"],
		 "epoch" =>	["day", "epoch"],
	     },
	     );

# (resolution,period) => list of pairs (resolution,period)
# Put "primary zoom target" as the first item in the list,
# as that is the target we set up in the client-side image map.

%zoom_in = (
	    "raw" => {
		"week" =>	["raw", "day",
				 "hr", "day"],
	    },
	    "5m" => {
		"week" =>	["5m", "day",
				 "hr", "day"],
	    },
	    "hr" => {
		"day" =>	["raw", "day"],
		"week" =>	["hr", "day",
				 "raw", "week"],
		"month" =>	["hr", "week"],
	    },
	    "day" => {
		"week" =>	["hr", "day",
				 "raw", "day"],
		"month" =>	["hr", "week",
				 "day", "week"],
		"year" =>	["day", "month"],
		"epoch" =>	["day", "month"],
	    },
	    "week" => {
		"month" =>	["hr", "day",
				 "raw", "day"],
		"year" =>	["day", "month"],
		"epoch" =>	["day", "month"],
	    },
	    );


sub img_names {
    my($line, $dsp, $res, $plot) = @_;
    my($file);

    $file = sprintf("%s.%s.%s.%s.png", $res, $plot, $line, $dsp);
    return(
	   sprintf("%HTMLPFX%/imgs/%s", $file),
	   sprintf("%s/imgs/%s", $docbase, $file)
	   );
}

%checker = ("hr"	=> \&same_day,
	    "5m"	=> \&same_day,
	    "raw"	=> \&same_day,
	    "day"	=> \&same_day,
	    "week"	=> \&same_week,
	    "month"	=> \&same_month);


sub regen_needed {
    my($f, $dsp, $res) = @_;
    my($dsp_t, $now, $modt, $now_d, $mod_d, $same_period);

    if (! -r $f || -z $f) { return 1; }
    $now = time;
    $modt = &modtime($f);

    # plots looking at values from today always require regen
    if (&looking_at_today($dsp, $res)) { return 1; }

    if (! &tm_in_datespec($modt, $dsp)) { return undef; }
    
    if (!defined($same_period = $checker{$res})) {
	return 1;		# just to be safe
    }
    
    return (! &$same_period($modt, $now));
}

sub plotit {
    my($line, $dsp, $plot, $res, $regen) = @_;
    my($img_out);
    my($plot_script) = "%TOPDIR%/plot/plot-" . $res;

    ($refname, $img_out) = &img_names($line, $dsp, $res, $plot);

    if ($regen || &regen_needed($img_out, $dsp, $res)) {
	$cmd = sprintf("%s -n %s -d %s -t %s -f png %s >%s",
		       $plot_script,
		       $line, $dsp, $plot,
		       $regen ? "-r" : "",
		       $img_out);

#	printf "$cmd<p>\n";
	$errfile="/tmp/plot-all.$$.err";
	$ret = system("($cmd) 2>$errfile 1>&2");
	$ret = $ret / 256;
	if ($ret != 0) {
	    print "<PRE>\n";
	    open (ERR, $errfile);
	    printf "$cmd\n";
	    print while (<ERR>);
	    close (ERR);
	    print "</PRE>\n";
	    unlink($img_out);
	    printf("Plot failed, ret = $ret\n");
	    return undef;
	}
	unlink($errfile);
	if (-s $img_out == 0) {
	    printf("Apparently, there is no data for $dsp / $line<br>\n");
	    printf("(zero-size plot file)\n");
	    unlink($img_out);
	    return undef;
	}
    }
    if (&tm_in_datespec(time, $dsp)) {
	$refname = sprintf("%CGIPFX%/ex-png/%s,%s",
			   &secs_to_expiry($res, $dsp),
			   $refname);
    }
    printf("<a href=\"%s\"><img src=\"%s\" ",
    	   $refname, $refname);
    printf("alt=\"[PNG plot]\" usemap=\"#plot\" /></a>\n");
}


sub forward_refs {
    my($line, $dsp, $res, $plot) = @_;
    my($pr_dsp, $nx_dsp, $pr_ex, $nx_ex, $pt, $dsp_t);
    my($base_tm, $pr_base_tm, $nx_base_tm, $ndays, $o_dsp, @l);
    my($z_dsp_t, $z_res, $ds, $head_done);
    my($map, $ref, $first, @ds, $dummy, $date);
    my(@l);

    # Get start of when we have data available

    @l = split(/\+/, $line); # use first if there's more than one

    if (!defined($date = &data_origin($l[0]))) {
	printf("<hr />\n");
	printf("Could not find origin for %s\n", $l[0]);
	printf("<hr />\n");
	return undef;
    }
    $origin = &date_to_tm($date);
    $dsp_t = &datespec_type($dsp);
    # Round down to start of "enclosing" period, except for epoch.
    if ($dsp ne "epoch") {
	($origin, $dummy) = &decode_datespec(&tm_to_datespec($origin, $dsp_t));
    }

    # Simultaneously construct a client-side image map.

    $map = "<map id=\"plot\" name=\"plot\">\n";


    # First, provide pointers to other type of plots covering the
    # same period with the same resolution.

    printf("<hr />\n");
    printf("You may further inspect for this period/port\n");
    printf("<ul>\n");
    foreach $pt (sort keys %{ $resolution_plots{$res}}) {
	printf("<li><a href=\"%s/%s,%s,%s,%s\">\n",
	       $ourname, $line, $dsp, $res, $pt);
	printf("%s</a></li>\n", $plot_title{$pt});
    }
    printf("</ul>\n");
    

    # Next, provide pointers to next and previous period
    # with same resolution

    $pr_dsp = &previous_datespec($dsp);
    $nx_dsp = &next_datespec($dsp);

    if (defined($pr_dsp) && defined($nx_dsp)) {
	($pr_base_tm, $ndays) = &decode_datespec($pr_dsp);
	($nx_base_tm, $ndays) = &decode_datespec($nx_dsp);

	# How far back do we have data available
	$pr_ex = ($pr_base_tm >= $origin);
	# Make sure we are not trying to see into the future
	$nx_ex = ! &tm_in_the_future($nx_base_tm);
	
	if ($pr_ex || $nx_ex) {
	    printf("or proceed to\n<ul>");
	    if ($pr_ex) {
		$ref = sprintf("href=\"%s/%s,%s,%s,%s\"",
		       $ourname, $line, $pr_dsp, $res, $plot);
		printf("<li><a %s>\n", $ref);
		printf("previous %s's %s plot</a>", 
		       $dsp_t,
		       $plot_title{$plot});
		$map .= sprintf("<area shape=\"rect\" coords=\"%s\" %s",
				"0,0,64,479", $ref);
		$map .= sprintf(" alt=\"Previous period\" />\n");
	    }
	    if ($nx_ex) {
		if ($pr_ex) { printf(", or</li>\n"); }
		else { printf("\n"); }
		$ref = sprintf("href=\"%s/%s,%s,%s,%s\"",
			       $ourname, $line, $nx_dsp, $res, $plot);
		printf("<li><a %s>\n", $ref);
		printf("next %s's %s plot</a></li>\n", 
		       $dsp_t, 
		       $plot_title{$plot});
		$map .= sprintf("<area shape=\"rect\" coords=\"%s\" %s",
				"625,0,639,479", $ref);
		$map .= sprintf(" alt=\"Next period\" />\n");
	    }
	    printf("</ul>\n");
	}
    }


    # Zoom out to see the bigger picture
    
    ($base_tm, $ndays) = &decode_datespec($dsp);

    @l = @{ $zoom_out{$res}{$dsp_t} };

    $head_done = 0;
    while(@l) {
	$z_res = shift(@l);
	$z_dsp_t = shift(@l);
	$o_dsp = &tm_to_datespec($base_tm, $z_dsp_t);

	if ($resolution_plots{$z_res}{$plot}) {
	    $ref = sprintf("href=\"%s/%s,%s,%s,%s\"",
			   $ourname, $line, $o_dsp, $z_res, $plot);
	    if (! $head_done) {
		printf("To \"zoom out\" and see the \"bigger picture\"\n");
		printf("you may want to view <ul>\n");
		$head_done = 1;
		$map .= sprintf("<area shape=\"rect\" coords=\"%s\" %s",
				"65,0,624,24", $ref);
		$map .= sprintf(" alt=\"Zoom out, %s plot in %s resolution\"",
				$z_dsp_t, $z_res);
		$map .= " />\n";
	    }
	    printf("<li>this %s's plot in ", $z_dsp_t);
	    printf("<a %s> %s resolution</a></li>\n", $ref, $z_res);
	}
    }
    if ($head_done) { printf("</ul>\n"); }


    # Next, do zooming in

    @l = @{ $zoom_in{$res}{$dsp_t} };

    $head_done = 0;
    $first = 1;
    while(@l) {
	my($dx, $x);

	$z_res = shift(@l);
	$z_dsp_t = shift(@l);

	if ($resolution_plots{$z_res}{$plot}) {
	    if (! $head_done) {
		printf("To \"zoom in\" and see the \"finer details\", ");
		printf("you may want to view\n<ul>\n");
		$head_done = 1;
	    }

	    printf("%s plots with %s resolution:\n<ul>\n",
		   $z_dsp_t, $z_res);

	    @ds = &expand_datespec($dsp, $z_dsp_t, $origin, $ndays);
	    if ($first) {
		if ($#ds != -1) {
		    # This is not exact; some weeks or months (when
		    # those plot types arrive) may be partial, but
		    # here we divide the entire interval equally among
		    # the components.
		    $dx = (624-65)/($#ds+1);
		    $x = 65;
		} else {
		    $first = 0;
		}
	    }
	    foreach $ds (@ds) {
		$ref = sprintf("href=\"%s/%s,%s,%s,%s\"",
			       $ourname, $line, $ds, $z_res, $plot);
		printf("<li><a %s> %s </a></li>\n",
		       $ref, &pretty_datespec($ds));
		if ($first) {
		    $map .= sprintf("<area shape=\"rect\" coords=\"%s\" %s",
				    sprintf("%d,24,%d,444",
					    $x, $x+$dx-1),
				    $ref);
		    $map .= sprintf(" alt=\"Zoom in to %s-res plot" .
				    " of %s\" />\n",
				    $z_res, &pretty_datespec($ds));
		    $x += $dx;
		}
	    }
	    $first = 0;
	    printf("</ul>\n");
	}
    }
    if ($head_done) { printf("</ul>\n"); }

    # Spit out map

    $map .= "</map>\n";
    print $map;
}

#
# Main
#

$doc = new CGI;

umask 0;			# make image files writeable

# open(STDERR, ">/tmp/err-$$");

if ($ENV{'QUERY_STRING'}) {
    $query = $ENV{'QUERY_STRING'};
    $pfx="";
} elsif ($ENV{'PATH_INFO'}) {
    $query = $ENV{'PATH_INFO'};
    $query =~ s/^\///;
    $pfx = "../";
} else {
    $pfx = "";
    $query = "@ARGV";
}

$ourname = sprintf("%splot-all", $pfx);

($line, $datespec, $res, $plot, $regen) = split(/\s*,\s*/,"$query");

if (!defined($datespec) || $datespec eq "") {
    $datespec = &yesterday_spec(); # default to show plot for previous day
    $exp = &secs_to_expiry("day", $datespec);
} elsif (&is_today($datespec)) {
    $exp = &secs_to_expiry($res, $datespec);
} else {
    $exp = 30*24*60*60;		# one month, really "eternally"
}

($base_tm, $nofdays) = &decode_datespec($datespec);

if (&looking_at_today($datespec, $res)) {
    print $doc->header(-type => "text/html",
		       -expires => sprintf("+%ds", $exp),
		       -Refresh => &secs_to_expiry($res, $datespec)
		       );
} else {
    print $doc->header(-type => "text/html",
		       -expires => sprintf("+%ds", $exp),
		       );
}

$title = "$line ";
$title .= $resolution_name{$res};
$title .= " ";
$title .= $plot_title{$plot};
$title .= " ";
$title .= &pretty_datespec($datespec);

# Prevent robot indexing, method supported by at least *some* robots...
# You should however probably also add a robots.txt file to your server, see
# http://info.webcrawler.com/mak/projects/robots/exclusion.html

print $doc->start_html(-title=>$title,
		       -meta=> { "robots" => "noindex, nofollow" }
		       );

# Do argument validation

@al = ($line, $datespec, $res, $plot, $regen);
if (defined($ai = &invalid_arg("[-A-Za-z0-9_.:\+]*", @al))) {
    printf("<h2>Invalid argument: %s</h2>\n", $al[$ai]);
    print $doc->end_html;
    print "\n";
    exit 1;
}

if (!defined($datespec)) {
    print "<h2>Sorry, can't decode date specification $datespec </h2>\n";
    print $doc->end_html;
    print "\n";
    exit 1;
}

if (&tm_in_the_future($base_tm)) {
    print "<h2>Sorry, can't look into the future </h2>\n";
    printf("May be you could try to see the " .
	   "<a href=\"%s/%s,%s,%s,%s\"> previous period (%s)</a> instead <p>", 
	   $ourname,
	   $line,
	   &previous_datespec($datespec),
	   $res, $plot,
	   &pretty_datespec(&previous_datespec($datespec)));
    print $doc->end_html;
    print "\n";
    exit 1;
}

print("<h2>$title</h2>\n");

# Resolution is encoded in plot-name

if ($resolution_plots{$res}{$plot}) {
    if (&plotit($line, $datespec, $plot, $res, $regen)) {
	printf("<hr />The above image \"clickable\" for zooming etc.\n");
	printf("A <a href=\"%s../stats/img-doc.html\">", $pfx);
	printf("brief explanation</a> is available.\n");
	&forward_refs($line, $datespec, $res, $plot);
    }
} else {
    printf("<h2>Sorry, do not know how to produce ");
    printf("plot %s in resolution %s</h2>\n", $plot, $res);
}

print $doc->end_html;
print "\n";
