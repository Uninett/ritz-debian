#! %PERL%

#
# $Id$
#

# Compute the average load per customer, present the top10 in a plot,
# with appropriate pointers to zoom in and out.

push(@INC, "%LIBDIR%");

$docbase = "%HTMLDIR%";

use CGI;
use strict;

use lib qw(%LIBDIR%);

use Zino::conn qw(read_desc select_types %ports);

require 'date.pl';
require 'search.pl';
require 'db-lookup.pl';
require 'utils.pl';


# Fields in traffic.kbit for average in and out
our(%fields) = (
    "day" => {
	"avg-in" => 5,
	"avg-out" => 6,
#	"busy-in" => 1,
#	"busy-out" => 2,
#	"busy-period" => "hour",
    },
    "week" => {
	"avg-in" => 7,
	"avg-out" => 8,
#	"busy-in" => 3,
#	"busy-out" => 4,
#	"busy-period" => "hour",
    },
    "month" => {
	"avg-in" => 7,
	"avg-out" => 8,
#	"busy-in" => 3,
#	"busy-out" => 5,
#	"busy-period" => "day",
    },
    );

our(%zoom_in) = (
    "week" => "day",
    "month" => "week",
    );

our(%zoom_out) = (
    "day" => "week",
    "week" => "month",
    );


sub find_report_file {
    my($dsp, $dsp_t) = @_;
    my($tm, $ndays) = &decode_datespec($dsp);
    my($s, $m, $h, $md, $mon, $y, $wd, $yd, $dst) = localtime($tm);

    if ($dsp_t eq "day") {
	return(sprintf("%REPDIR%" . "/%d-%02d/%02d/traffic.kbit",
		       $y+1900, $mon+1, $md));
    } elsif ($dsp_t eq "week") {
	return(sprintf("%REPDIR%" . "/weekly/%d/%02d/traffic.kbit",
		       $y+1900, &weekno($tm)));
    } elsif ($dsp_t eq "month") {
	return(sprintf("%REPDIR%" . "/monthly/%d/%02d/traffic.kbit",
		       $y+1900, $mon+1));
    } else {
	&err("Unsupported date-spec type: $dsp_t");
    }
}


sub get_data {
    my($dsp) = @_;
    my($dsp_t) = &datespec_type($dsp);
    my($f) = &find_report_file($dsp, $dsp_t);
    my(%a_in, %a_out);
    our(%avg_in, %avg_out);
    our(%ports);
    our(%fields);
#    our(%b_in, %b_out);
#    our(%busy_in, %busy_out);
    
    open(IN, $f) || &err("Could not open $f: $!");
    while(<IN>) {
	chomp; split;
	my $p = $_[0];
	$a_in{$p} = $_[$fields{$dsp_t}->{"avg-in"}];
	$a_out{$p} = $_[$fields{$dsp_t}->{"avg-out"}];
#	$b_in{$p} = $_[$fields{$dsp_t}->{"busy-in"}];
#	$b_out{$p} = $_[$fields{$dsp_t}->{"busy-in"}];
    }
    close(IN);

    foreach my $c (&select_types("cust", keys %ports)) {
	foreach my $p (@{ $ports{$c} }) {
	    $avg_in{$c} += $a_in{$p};
	    $avg_out{$c} += $a_out{$p};
#	    $busy_in{$c} += $b_in{$p};
#	    $busy_out{$c} += $b_out{$p};
	}
    }
    foreach my $c (keys %avg_in) {
	$avg_in{$c} = $avg_in{$c} / 1000.0;
	$avg_out{$c} = $avg_out{$c} / 1000.0;
    }
}

sub make_plot {
    my($imgname, $when, $period, $inref, $outref) = @_;

    my($total) = 0;

    foreach my $k (keys %{ $inref }) {
	$total += $inref->{$k};
	$total += $outref->{$k};
    }

    my(@sorted_names) = sort {
	&max($inref->{$b}, $outref->{$b}) <=>
	    &max($inref->{$a}, $outref->{$a})
    } keys %{ $inref };

    my(@top10) = @sorted_names[0..9];

    my($selsum) = 0;
    foreach my $k (@top10) {
	$selsum += $inref->{$k};
	$selsum += $outref->{$k};
    }
    my($percentage) = sprintf("%.1f", $selsum * 100.0 / $total);

    my($datafile) = "/tmp/data$$";
    open(OUT, ">" . $datafile) || die "Could not write $datafile: $!";
    foreach my $k (@top10) {
	printf(OUT "%s %f %f\n", $k, $inref->{$k}, $outref->{$k});
    }
    close(OUT);

    my($imgfile) = "%IMGDIR%/" . $imgname . ".png";

    my($plotfile) = "/tmp/plot$$";
    open(OUT, ">" . $plotfile) || die "Could not write $plotfile: $!";
    print OUT <<EOF;
set ylabel "Mbit/s"
set title "Top 10 customers by traffic with %ISPNAME% $when, $period"
set xlabel "Top 10 accounts for $percentage% of total"
set style histogram
set style data histogram
set style fill solid 0.6 border -1
set term png small
set output "$imgfile.new"
set yrange [0:]
plot "$datafile" using 2 title "Into %ISPNAME%", "" using 3:xticlabels(1) title "Out from %ISPNAME%"

EOF

    close(OUT);

    system("gnuplot $plotfile");

#    unlink($plotfile);
#    unlink($datafile);

    rename($imgfile . ".new", $imgfile);

    my($custlist) = "%IMGDIR%/" . $imgname . ".cust";

    open(OUT, ">" . $custlist)	||
	die "Could not write $custlist: $!";
    print(OUT join("\n", @top10));
    print(OUT "\n");
    close(OUT);

    return @top10;
}

sub plotname {
    my($dsp, $type) = @_;

    return sprintf("top10-%s-%s", $dsp, $type);
}

sub err {
    my($s) = @_;
    our($q);
    
    print $q->h1($s);
    print $q->end_html;

    printf(STDERR "top10: %s", $s);
    exit(1);
}

#
# Main
#

our $q = new CGI;

my $cf = "%DESCFILE%";

# Get list of customers
&read_desc($cf);

umask 0;			# make image files writeable

my $dsp = $q->param("dsp");
my $dsp_t = &datespec_type($dsp);
my $force = $q->param("force");	# caching, for the future, force regen

print $q->header();
print $q->start_html(
    -title => "Top 10 customers $dsp",
    );

our(%avg_in, %avg_out);

&get_data($dsp);

# my $bplotfn = "%IMGDIR%/" . &plotname($dsp, "busy") . ".png";
# my (@busy) = &make_plot($bplotfn, &pretty_datespec($dsp),
# 			$fields{$dsp_t}->{"busy-period"},
# 			\%busy_in, \%busy_out);

my $plotname = &plotname($dsp, "avg");

my (@customers) = &make_plot($plotname,
			     &pretty_datespec($dsp), "average",
			     \%avg_in, \%avg_out);

my($head_template) = "%TOPDIR%/top10.head";
my($title) = sprintf("Top 10 customers in %s",
		     &pretty_datespec($dsp));
if (-f $head_template) {
    open(IN, $head_template) || die "Could not open $head_template: $!";
    while(<IN>) {
	if (/#TITLE#/) {
	    s/#TITLE#/$title/;
	}
	print $_;
    }
} else {
    print $q->h1($title);
}

print $q->hr;

my $mapname = $plotname;

printf("<img src=\"../imgs/%s.png\" alt=\"%s\" " .
       "usemap=\"#%s\" border=\"0\" />\n",
       $plotname, $plotname, $mapname);

my($x, $top, $bot) = (94, 38, 440);
printf("<map id=\"%s\" name=\"%s\">\n", $mapname, $mapname);
foreach my $c (@customers) {
    printf("  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	   $x, $top, $x+51, $bot);
    $x += 51;
    printf(" href=\"%CGIPFX%/r-all?q=all&amp;name=%s\" " .
	   "alt=\"current plot for %s\" />\n", $c, $c);
}

#
# Pointers to previous and possibly next
#

my($leftx, $rightx, $endx, $endy) = (61, 622, 640, 480);
my($prev_dsp) = &previous_datespec($dsp);
my($next_dsp) = &next_datespec($dsp);

printf("  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
       0, $top, $leftx, $bot);
printf(" href=\"%CGIPFX%/top10?dsp=%s\" " .
       "alt=\"previous top10, for %s\" />\n", $prev_dsp, $prev_dsp);

my($nx_base_tm, $ndays) = &decode_datespec($next_dsp);
my($url, $alt);
# Can't look at data not yet processed, so look at "current" instead.
if ($nx_base_tm + $ndays * 86400 > time) {
    $url = "../top10.html";
    $alt = "current top10";
} else {
    $url = sprintf("%CGIPFX%/top10?dsp=%s", $next_dsp);
    $alt = sprintf("top10 for %s", $next_dsp);
}
printf("  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
       $rightx, $top, $endx, $bot);
printf(" href=\"%s\" alt=\"%s\" />\n", $url, $alt);

#
# Zoom in
#

my($base_tm, $ndays) = &decode_datespec($dsp);
my($z_type) = $zoom_in{$dsp_t};
if (defined($z_type)) {
    my(@dsl) = &expand_datespec($dsp, $z_type, $base_tm, $ndays);
    $x = $leftx;
    my($dx) = ($rightx - $leftx) / ($#dsl + 1);

    foreach my $ds (@dsl) {
	printf("  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	       $x, $bot, $x + $dx-1, $endy);
	printf(" href=\"%CGIPFX%/top10?dsp=%s\" " .
	       "alt=\"Zoom in to top10 for %s\" />\n", $ds, $ds);
	
	$x += $dx;
    }
}

#
# Zoom out
#

$z_type = $zoom_out{$dsp_t};
if (defined($z_type)) {
    my($o_dsp) = &tm_to_datespec($base_tm, $z_type);
    my($tm, $ndays) = &decode_datespec($o_dsp);
    # Now is not within current month:
    if ($^T > $tm + $ndays * 86400) {
	# top, middle
	printf("  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	       $leftx, 0, $rightx, $top);
	printf(" href=\"%CGIPFX%/top10?dsp=%s\"", $o_dsp);
	printf(" alt=\"Zoom out to top10 for %s\" />\n", $o_dsp);
    }

    # top, left, "previous"
    $prev_dsp = &previous_datespec($o_dsp);
    printf("  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	   0, 0, $leftx, $top);
    printf(" href=\"%CGIPFX%/top10?dsp=%s\"", $prev_dsp);
    printf(" alt=\"top10 for %s\" />\n", $prev_dsp);

    # top, right, possibly "next"
    $next_dsp = &next_datespec($o_dsp);
    ($tm, $ndays) = &decode_datespec($next_dsp);
    if ($^T > $tm + $ndays * 86400) {
	printf("  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	       $rightx, 0, $endx, $endy);
	printf(" href=\"%CGIPFX%/top10?dsp=%s\"", $next_dsp);
	printf(" alt=\"top10 for %s\" />\n", $next_dsp);
    }
}


print("</map>\n");

print $q->hr;

my($tail_template) = "%TOPDIR%/top10.tail";
my($img_help) = "/pics/zoom-top10.png";
if (-f $tail_template) {
    open(IN, $tail_template) || die "Could not open $tail_template: $!";
    while(<IN>) {
	if (/#ZOOMIMG#/) {
	  s:#ZOOMIMG#:$img_help:;
	}
	print $_;
    }
} else {
    printf("<p>\n");
    printf("An image showing the various navigation areas\n");
    printf("can be seen <a href=\"%s\">", $img_help);
    printf("here</a>\n");
}

print $q->hr;

print $q->end_html;

