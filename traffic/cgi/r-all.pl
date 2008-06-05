#!%PERL%
#
# $Id$
#

# Copyright (c) 2008
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
# 3. Neither the name of UNINETT or NORDUnet nor the names
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

package Zino::rrd;

use lib "%LIBDIR%";

use CGI ();
CGI->compile();
use IPC::Shareable ();
use RRDs;
use File::Basename;

use Zino::conn qw(read_desc %fullname);

use strict;
use warnings;

$^T = time;			# -M etc. relative to this invocation

my %img_size;
tie %img_size, 'IPC::Shareable', "Zpng", { mode => 0666,
					   create => 1,
};

my($descfile);
my($lastread_desc);

$descfile = "%DESCFILE%";
$lastread_desc = 0;
    
sub modtime {
    my($f) = @_;
    my(@a);
    (@a = stat($f)) || return undef;
    return $a[9];
}

if (&modtime($descfile) > $lastread_desc) {
    &read_desc($descfile);
    $lastread_desc = $^T;
}


my %xgrid = (
    "day"   => "HOUR:1:HOUR:3:HOUR:3:0:%H:%M",
    "daymax"=> "HOUR:1:HOUR:3:HOUR:3:0:%H:%M",
    "week"  => "HOUR:12:DAY:1:DAY:1:86400:%a %d",
    "weekmax"=> "HOUR:12:DAY:1:DAY:1:86400:%a %d",
    "month" => "DAY:1:WEEK:1:WEEK:1:604800:Week %V",
    "monthmax" => "DAY:1:WEEK:1:WEEK:1:604800:Week %V",
    "3month"=> "DAY:7:MONTH:1:MONTH:1:2592000:%h %Y",
    "year"  => "MONTH:1:MONTH:3:MONTH:1:2592000:%h",
    "2year" => "MONTH:1:MONTH:3:MONTH:3:2592000:%h",
);

my %sample_len = (
    "day"  => "5 minutes",
    "daymax"=> "5 minutes",
    "week" => "30 minutes",
    "weekmax" => "30 minutes",
    "month"=> "2 hours",
    "monthmax"=> "2 hours",
    "3month"=>"24 hours",
    "year" => "24 hours",
    "2year"=> "24 hours",
);

my %title = (
    "day"   => "Last 24 hours average traffic",
    "daymax"=> "Last 24 hours peak traffic",
    "week"  => "Last week average traffic",
    "weekmax"=> "Last week peak traffic",
    "month" => "Last 31 days average traffic",
    "monthmax"=> "Last 31 days peak traffic",
    "3month"=> "Last 3 months",
    "year"  => "Last year",
    "2year" => "Last 2 years",
    
    );

my %refresh = (
    "day"  => 5 * 60,
    "daymax"=> 5 * 60,
    "week" => 30 * 60,
    "weekmax"=> 30 * 60,
    "month"=> 2 * 60 * 60,
    "monthmax"=> 2 * 60 * 60,
    "3month"=>24 * 60 * 60,
    "year" => 24 * 60 * 60,
    "2year"=> 24 * 60 * 60,
);

my %delta_t = (
    "day"  => "-1day",
    "daymax"=> "-1day",
    "week" => "-7days",
    "weekmax" => "-7days",
    "month"=> "-31days",
    "monthmax"=> "-31days",
    "3month"=>"-3months",
    "year" => "-1year",
    "2year"=> "-2year",
);

my %plot_type = (
    "day"      => "avg",
    "week"     => "avg",
    "month"    => "avg",
    "daymax"   => "max",
    "weekmax"  => "max",
    "monthmax" => "max",
    "3month"   => "combined",
    "year"     => "combined",
    "2year"    => "combined",
    );

my @order = ("day", "daymax", "week", "weekmax",
	     "month", "monthmax", "3month", "year", "2year");

my($isp) = "%ISPNAME%";
my($rrddir) = "%RRDDIR%";
my($pngdir) = "%IMGDIR%";


sub small_png_file {
    my($name, $type) = @_;

    my $png = $pngdir . "/" . $name . "-" . $type . "-small.png";
    return $png;
}

sub big_png_file {
    my($name, $type) = @_;

    my $png = $pngdir . "/" . $name . "-" . $type . ".png";
    return $png;
}

sub make_plot {
    my($name, $type, $rrd, $png, $w, $h, @fonts) = @_;
    my($avg, $x, $y);
    my($pt);

    $pt = $plot_type{$type};

    my(@l) = ($png,
	      "-a", "PNG",
	      "-w", $w,
	      "-h", $h,
	);
    push(@l, ("-s", "end" . $delta_t{$type}));
    push(@l, ("--color", "MGRID#000000",
	      "-v", "bit/s",
	      "--alt-autoscale-max",
	      "--alt-y-grid",
	      "-l", 0,
	 ));
    push(@l, ("-x", $xgrid{$type}));
    push(@l, ("-t", sprintf("%s traffic with %s", $isp, $name)));
    if (@fonts) {
	push(@l, @fonts);
    }
    push(@l, (sprintf("DEF:in=%s:In:AVERAGE", $rrd),
	      sprintf("DEF:out=%s:Out:AVERAGE", $rrd),
	      sprintf("DEF:inmax=%s:In:MAX", $rrd),
	      sprintf("DEF:outmax=%s:Out:MAX", $rrd)));

    if ($pt eq "max") {
	push(@l, (
		 "VDEF:avg_in=inmax,AVERAGE",
		 "VDEF:avg_out=outmax,AVERAGE",
		 "VDEF:max_in=inmax,MAXIMUM",
		 "VDEF:max_out=outmax,MAXIMUM",
		 "VDEF:cur_in=inmax,LAST",
		 "VDEF:cur_out=outmax,LAST",
	     ));
	push(@l, ("AREA:inmax#ff6699:Max In "));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:avg_in:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:max_in:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:cur_in:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
	push(@l, ("LINE1:outmax#800000:Max Out"));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:avg_out:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:max_out:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:cur_out:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
    } elsif ($pt eq "avg") {
	push(@l, (
		 "VDEF:avg_in=in,AVERAGE",
		 "VDEF:avg_out=out,AVERAGE",
		 "VDEF:max_in=in,MAXIMUM",
		 "VDEF:max_out=out,MAXIMUM",
		 "VDEF:cur_in=in,LAST",
		 "VDEF:cur_out=out,LAST",
	     ));
	push(@l, ("AREA:in#33cccc:Avg In "));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:avg_in:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:max_in:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:cur_in:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
	push(@l, ("LINE2:out#006699:Avg Out"));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:avg_out:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:max_out:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:cur_out:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
    } else {
	push(@l, (
		 "VDEF:max_avg_in=inmax,AVERAGE",
		 "VDEF:max_avg_out=outmax,AVERAGE",
		 "VDEF:max_max_in=inmax,MAXIMUM",
		 "VDEF:max_max_out=outmax,MAXIMUM",
		 "VDEF:cur_in=inmax,LAST",
		 "VDEF:cur_out=outmax,LAST",
	     ));
	push(@l, (
		 "VDEF:avg_avg_in=in,AVERAGE",
		 "VDEF:avg_avg_out=out,AVERAGE",
		 "VDEF:avg_max_in=in,MAXIMUM",
		 "VDEF:avg_max_out=out,MAXIMUM",
		 "VDEF:avg_cur_in=in,LAST",
		 "VDEF:avg_cur_out=out,LAST",
	     ));
	push(@l, ("AREA:in#33cccc:Avg In "));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:avg_avg_in:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:avg_max_in:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:avg_cur_in:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
	push(@l, ("LINE2:out#006699:Avg Out"));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:avg_avg_out:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:avg_max_out:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:avg_cur_out:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
	push(@l, ("LINE1:inmax#ff6699:Max In "));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:max_avg_in:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:max_max_in:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:cur_in:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
	push(@l, ("LINE1:outmax#800000:Max Out"));
	push(@l, ("COMMENT:\\tAvg\\:",
		  "GPRINT:max_avg_out:%6.2lf%s",
		  "COMMENT:Max\\:",
		  "GPRINT:max_max_out:%6.2lf%s",
		  "COMMENT:Last\\:",
		  "GPRINT:cur_out:%6.2lf%s",
		  "COMMENT:\\n",
	     ));
    }
    if ($pt eq "combined") {
	push(@l,
	     (sprintf("COMMENT:Each averaged data point is averaged over %s",
		      $sample_len{$type})));
    }
    if ($pt eq "combined" || $pt eq "max") {
	push(@l,
	     (sprintf("COMMENT:Each max data point is 5min max in %s interval",
		      $sample_len{$type})));
    } else {
	push(@l,
	     (sprintf("COMMENT:Each data point is averaged over %s",
		      $sample_len{$type})));
    }	
    push(@l, ("COMMENT:\\n"));
    push(@l, (sprintf("COMMENT:Direction is as seen from %s\\j", $isp)));
    push(@l, ("GPRINT:cur_in:Updated %H\\:%M %a %d %b %Y\\r:strftime",
	 ));

    ($avg, $x, $y) = RRDs::graph(@l);

    my $err = RRDs::error;
    if ($err) {
	return (undef, undef, $err);
    } else {
	return ($png, $x, $y);
    }
}

sub make_small_plot {
    my($name, $type) = @_;

    my $rrd = $rrddir . "/" . $name . ".rrd";
    my $png = &small_png_file($name, $type);

    if (!-f $rrd) {
	&err(sprintf("Cannot find data for '%s'", $name));
    }

    return &make_plot($name, $type, $rrd, $png, 400, 200);
}

sub make_big_plot {
    my($name, $type) = @_;

    my $rrd = $rrddir . "/" . $name . ".rrd";
    my $png = &big_png_file($name, $type);

    if (!-f $rrd) {
	&err(sprintf("Cannot find data for '%s'", $name));
    }

    my @fonts = (
	"--font", "AXIS:11:/usr/X11R6/lib/X11/fonts/TTF/Vera.ttf",
	"--font", "UNIT:11:/usr/X11R6/lib/X11/fonts/TTF/Vera.ttf",
	"--font", "TITLE:13:/usr/X11R6/lib/X11/fonts/TTF/VeraBd.ttf",
	"--font", "LEGEND:10:/usr/X11R6/lib/X11/fonts/TTF/Vera.ttf",
	);

    return &make_plot($name, $type, $rrd, $png, 800, 600, @fonts);
}

sub ensure_img_exists {
    my($name, $type, $size) = @_;
    my($png);
    my($x, $y);
    our($q);
    my($img_size_unknown, $old_png_file);

    $img_size_unknown = $old_png_file = 0;

    if ($size eq "big") {
	$png = &big_png_file($name, $type);
    } else {
	$png = &small_png_file($name, $type);
	$size="small";
    }

    if (!defined($img_size{$type,$size,"x"}) &&
	!defined($img_size{$name,$type,$size,"x"}))
    {
	$img_size_unknown = 1;
    }
    if (! -f $png || (-M _)*24*3600 > $refresh{$type}) {
	$old_png_file = 1;
    }

    if ($img_size_unknown || $old_png_file || $q->param("force")) {
	if ($size eq "big") {
	    ($png, $x, $y) = &make_big_plot($name, $type);
	} else {
	    ($png, $x, $y) = &make_small_plot($name, $type);
	}
	if (!defined($png)) {
	    &err(sprintf("Error making plot for %s / %s: %s",
			 $name, $type, $y));
	    return undef;
	}
	if (!defined($img_size{$type,$size,"x"})) {
	    $img_size{$type,$size,"x"} = $x;
	    $img_size{$type,$size,"y"} = $y;
	} elsif ($img_size{$type,$size,"x"} != $x &&
		 $img_size{$type,$size,"y"} != $y) {
	    $img_size{$name,$type,$size,"x"} = $x;
	    $img_size{$name,$type,$size,"y"} = $y;
	}
    } else {
	# return cached size
	if (defined($img_size{$name,$type,$size,"x"})) {
	    $x = $img_size{$name,$type,$size,"x"};
	    $y = $img_size{$name,$type,$size,"y"};
	} else {
	    $x = $img_size{$type,$size,"x"};
	    $y = $img_size{$type,$size,"y"};
	}
    }
    # Now $png exists with size $x, $y
    return($png, $x, $y);
}

sub start_doc {
    my($q, $type, $title) = @_;
    
    my $text = $q->header(-type => "text/html; charset=iso-8859-1",
			  -expires => sprintf("+%ds", $refresh{$type}),
			  -refresh => $refresh{$type},
	);

    my $style = <<EOF
  <style type="text/css">
    body, h1, h2, h3, p, span, div { 
	font-family: verdana, helvetica, arial, sans-serif;
	font-size: small;
    }
    body { 
	background-color: #ffffff;
        color: #000000;
    }    
    table.invisiblebox {
        border-width: thin;
        border-top: 0px;
        border-bottom: 0px;
        border-left: 0px;
        border-right: 0px;
        border-color: #999;
        border-style: solid;
        padding: 0px 0px 0px 0px;
	margin: 0px 0px 0px 0px;
	white-space: nowrap;
	width: 1%;
    }
    .ruler {
	background-color: #999999;
        border: 0px;
        height: 1px;
    }
  </style>
  <title>
EOF
;
    $text .= $q->start_html(-title => $title,
			    -style => { -code => $style },
			    -meta=> { "robots" => "noindex, nofollow" },
    );
    return $text;
}

sub show_all {
    my($name, $url) = @_;
    my($png, $x, $y);
    my($n) = 0;
    our(%fullname);
    my($fn);

    my $text = <<EOF
  <table cellpadding="3" border="0">
    <tr>
      <td>
EOF
;
    $text .= sprintf("        <h2>%s traffic with %s", $isp, $name);
    if (defined($fullname{$name})) {
	$text .= " - ";
	$text .= $fullname{$name};
    }
    $text .= "</h2>";
    $text .= <<EOF

      </td>
    </tr>
  </table>
  <table class="invisiblebox">
    <tr>
      <td colspan="2"><hr class="ruler" /></td>
    </tr>
EOF
;

    foreach my $type (@order) {
	($png, $x, $y) = &ensure_img_exists($name, $type, "small");
	if ($n % 2 == 0) {
	    $text .= "    <tr>\n";
	}
	$text .= "      <td>\n";
	$text .= "      <table class=\"invisiblebox\">\n";
	$text .= "        <tr>\n";
	$text .= sprintf("          " .
			 "<td><h3>%s</h3></td>\n", $title{$type});
	$text .= "        </tr>\n";

	$text .= "        <tr>\n";
	my($bpng) = basename($png);
	$text .= sprintf("          " .
			 "<td><a href=\"%s?q=one&amp;name=%s&amp;type=%s\">",
	       $url, $name, $type);
	$text .= sprintf("<img src=\"%s?q=img&amp;img=%s&amp;type=%s\" ",
	       $url, $bpng, $type);
	$text .= sprintf("alt=\"small %s %s graph\" ", $name, $type);
	$text .= sprintf("width=\"%d\" height=\"%d\" /></a></td>\n", $x, $y);
	$text .= "        </tr>\n";
	$text .= "      </table>\n";
	$text .= "      </td>\n";
	$n++;
	if ($n % 2 == 0) {
	    $text .= "    </tr>\n";
	}
    }
    if ($n % 2 != 0) {
	$text .= "    </tr>\n";
    }
    $text .= "  </table>\n";
    return $text;
}

sub show_one {
    my($name, $type, $url) = @_;
    my($png, $x, $y);

    my $text = <<EOF
   <table cellpadding="3" border="0">
     <tr>
       <td>
EOF
;
    $text .= sprintf("        <h2>%s traffic with %s", $isp, $name);
    if (defined($fullname{$name})) {
	$text .= " - ";
	$text .= $fullname{$name};
    }
    $text .= sprintf(", %s</h2>", $title{$type});

    $text .= "</h2>";
    $text .= <<EOF

      </td>
    </tr>
  </table>
  <table class="invisiblebox">
    <tr>
      <td colspan="2"><hr class="ruler" /></td>
    </tr>
EOF
;

    ($png, $x, $y) = &ensure_img_exists($name, $type, "big");
    my($bpng) = basename($png);
    $text .= "    <tr>\n      <td>";
    $text .= sprintf("<img src=\"%s?q=img&amp;img=%s&amp;type=%s\" ",
		     $url, $bpng, $type);
    $text .= sprintf("alt=\"big %s %s graph\" ", $name, $type);
    $text .= sprintf("width=\"%d\" height=\"%d\" /></td>\n", $x, $y);
    $text .= <<EOF
   </tr>
  </table>
EOF
;
    return $text;
}

sub err {
    my($msg) = @_;
    our($q);

    print $q->header("text/html");
    print $q->start_html("Error");
    printf("<h2>%s</h2>", $msg);
    print $q->end_html();
    exit 0;
}

sub send_img {
    my($q, $bpng, $type) = @_;

    $bpng = basename($bpng);
    my $png = $pngdir . "/" . $bpng;

    open(IN, $png) ||
	&err(sprintf("Could not open image file %s: $!", $bpng));

    print $q->header(-type => "image/png",
		     -expires => sprintf("+%ds", $refresh{$type}),
		     -refresh => $refresh{$type},
	);

    my $bytes = "";
    while(my $n = sysread(IN, $bytes, 1024)) {
	syswrite(STDOUT, $bytes, $n);
    }
    close(IN);
}


#
# Main
#

local our $q = new CGI;
my $qt = $q->param("q");
my $me = $q->url(-relative => 1);
my($text, $name, $type, $img);

select(STDOUT); $| = 1;		# unbuffer, we only print once

if (!defined($qt)) {
    &err("No query type");
}
if ($qt eq "img") {
    $img = $q->param("img");
    $type = $q->param("type");
    if (!defined($refresh{$type})) {
	&err(sprintf("Unrecognized type: %s", $type));
    }
    &send_img($q, $img, $type);
} elsif ($qt eq "all") {
    $name = $q->param("name");
    if (!defined($name)) {
	&err("No name given");
    }
    $text = &start_doc($q, "day",
			  sprintf("%s traffic with %s",
				  $isp, $name));
    $text .= &show_all($name, $me);
    $text .= $q->end_html();
    $text .= "\n";
    print $text;
} elsif ($qt eq "one") {
    $name = $q->param("name");
    $type = $q->param("type");

    if (!defined($name)) {
	&err("No name given");
    }
    if (!defined($type)) {
	&err("No type given");
    }
    if (!defined($refresh{$type})) {
	&err(sprintf("Plot type '%s' unrecognized", $type));
    }
    $text = &start_doc($q, $type,
		       sprintf("%s traffic with %s",
			       $isp, $name));
    $text .= &show_one($name, $type, $me);
    $text .= $q->end_html();
    $text .= "\n";
    print $text;
}
