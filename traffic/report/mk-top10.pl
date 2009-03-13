#! %PERL%

# $Id$

# Produce an initial version of "top 10" traffic plots for
# the customers of this ISP.
#
# This uses the "cust-load-now.pl" script, sorts the output
# in 4 different ways, makes 4 different static .png images,
# and writes a wrapper HTML page around the images, with
# auto-refresh, relying on if-modified-since processing by
# the web client + server to take care of caching.

push(@INC, "%LIBDIR%");
use lib qw(%LIBDIR%);

use File::stat;
use POSIX qw(strftime);

use Zino::conn qw(read_desc select_types %fullname %ports);

require 'getopts.pl';
require 'utils.pl';
require 'date.pl';


sub make_plot {
    my($plotname, $title_suffix, $when,
       $href, $hdir, $href2, $hdir2) = @_;

    my($total);
    foreach my $k (keys %{ $href }) {
	$total += $href->{$k};
	$total += $href2->{$k};
    }
    my(@sorted_names) = sort {
	&max($href->{$b}, $href2->{$b}) <=>
	    &max($href->{$a}, $href2->{$a})
    } keys %{ $href };
    my(@top10) = @sorted_names[0..9];

    my($selsum);
    foreach my $k (@top10) {
	$selsum += $href->{$k};
	$selsum += $href2->{$k};
    }
    my($percentage) = sprintf("%.1f", $selsum * 100.0 / $total);

    my($datafile) = "/tmp/data$$";
    open(OUT, ">" . $datafile) || die "Could not write $datafile: $!";
    foreach my $k (@top10) {
	printf(OUT "%s %f %f\n", $k, $href->{$k}, $href2->{$k});
    }
    close(OUT);

    my($imgfile) = "%IMGDIR%/" . $plotname . ".png";

    my($plotfile) = "/tmp/plot$$";
    open(OUT, ">" . $plotfile) || die "Could not write $plotfile: $!";
    print OUT <<EOF;
set ylabel "Mbit/s"
set title "Top 10 customers by traffic with %ISPNAME%, $title_suffix"
set xlabel "Traffic per $when,    accounts for $percentage% of total"
set style histogram
set style data histogram
set style fill solid 0.6 border -1
set term png small
set output "$imgfile.new"
set yrange [0:]
plot "$datafile" using 2 title "$hdir %ISPNAME%", "" using 3:xticlabels(1) title "$hdir2 %ISPNAME%"
EOF
    close(OUT);

    system("gnuplot $plotfile");

    unlink($plotfile);
    unlink($datafile);

    rename($imgfile . ".new", $imgfile);

    return @top10;
}


#
# Convert some common .se/.no letters into html equivalents
#

sub htmlize {
    my($s) = @_;

    $s =~ s/&/&amp;/g;
    $s =~ s/\x{E4}/&auml;/g;
    $s =~ s/\x{C4}/&Auml;/g;
    $s =~ s/\x{F6}/&ouml;/g;
    $s =~ s/\x{D6}/&Ouml;/g;
    $s =~ s/\x{E5}/&aring;/g;
    $s =~ s/\x{C5}/&Aring;/g;
    $s =~ s/\x{F8}/&oslash;/g;
    $s =~ s/\x{D8}/&Oslash;/g;
    $s =~ s/\x{E9}/&eacute;/g;
    $s =~ s/\x{C9}/&Eacute;/g;

    return $s;
}

sub modtime_str {
    my($f) = @_;
    my($sb) = stat($f);
    
    return strftime("%H:%M %d %b %Y", localtime($sb->mtime));
}


sub printit {
    my($fh, $picname, @customers) = @_;
    our(%fullname);
    my($mapname) = $picname;

    printf($fh "<img src=\"imgs/%s.png\" alt=\"%s\" " .
	   "usemap=\"#%s\" border=\"0\" />\n",
	   $picname, $picname, $mapname);
    my($x, $top, $bot);

    $top = 38;
    $bot = 440;
    $x = 94;

    my($dx) = 51 * 10 / ($#customers + 1);

    printf($fh "<map id=\"%s\" name=\"%s\">\n", $mapname, $mapname);
    foreach my $c (@customers) {
	printf($fh "  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	       $x, $top, $x+51, $bot);
	$x += $dx;
	printf($fh " href=\"%CGIPFX%/r-all?q=all&amp;name=%s\" " .
	       "alt=\"current plot for %s\" />\n", $c, $c);
    }

    # Where the graph proper starts
    my($leftx, $topy, $boty) = (61, 38, 440);

    # Add zoom decoration to yesterday and previous week

    my($dsp) = &tm_to_datespec($^T - 86400, "day");
    printf($fh "  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	   0, $topy, $leftx, $boty);
    printf($fh " href=\"%CGIPFX%/top10?dsp=%s\"", $dsp);
    printf($fh " alt=\"Top10 for yesterday\" />\n");

    my($dsp) = &tm_to_datespec($^T, "week");
    my($prev_week) = &previous_datespec($dsp);
    printf($fh "  <area shape=\"rect\" coords=\"%d,%d,%d,%d\"",
	   0, 0, $leftx, $topy);
    printf($fh " href=\"%CGIPFX%/top10?dsp=%s\"", $prev_week);
    printf($fh " alt=\"Top10 for last week\" />\n");


    printf($fh "</map>\n");
}

sub read_template {
    my($f) = @_;
    our(@head_lines, @tail_lines);

    open(IN, $f) || die "Could not open $f: $!";
    while(<IN>) {
	chomp;
	split(/\s+/, $_, 2);

	if (/^head/) {
	    my($marker) = $_[1];
	    while ($_ ne $marker) {
		$_ = <IN>;
		chomp;
		if ($_ ne $marker) {
		    push(@head_lines, $_);
		}
	    }
	}

	if (/^tail/) {
	    my($marker) = $_[1];
	    while($_ ne $marker) {
		$_ = <IN>;
		chomp;
		if ($_ ne $marker) {
		    push(@tail_lines, $_);
		}
	    }
	}
    }
    close(IN);
}


sub process_data {
    my($desc) = @_;
    my(%last_in, %last_out, %h_in, %h_out);
    our(@head_lines, @tail_lines);

    $now = &modtime_str("%TOPDIR%/reports/load-now.txt");

    open(IN, "%TOPDIR%/bin/cust-load-now -c $desc |") ||
	die "Could not get customer statistics: $!";
    while(<IN>) {
	chomp; split;
	my($n) = $_[0];
	$last_in{$n} = $_[1];
	$last_out{$n}= $_[2];
	$h_in{$n} = $_[3];
	$h_out{$n}= $_[4];
    }
    close(IN);

    my(@last) = &make_plot("top10-last", "last sample",
			       $now, \%last_in, "Into", \%last_out, "Out from");
    my(@last_h) = &make_plot("top10-1h", "last hour",
			    $now, \%h_in, "Into", \%h_out, "Out from");

    my($htmlout) = "%HTMLDIR%/" . "top10.html";
    open(OUT, ">" . $htmlout . ".new") ||
	die "Could not write $htmlout.new: $!";

    print OUT (join("\n", @head_lines));
    printf(OUT "<hr />\n");
    &printit(OUT, "top10-last", @last);
    printf(OUT "<hr />\n");
    &printit(OUT, "top10-1h", @last_h);

    my $ms;
    $ms =  '^(Uppdaterad|Updated|Oppdatert): ';
    $ms .= '\d+-\d+-\d+ \d+:\d+:\d+$';

    foreach my $l (@tail_lines) {
	if ($l =~ /$ms/o) {
	    printf(OUT "%s: %s\n", $1,
		   strftime("%Y-%m-%d %H:%M:%S", localtime($^T)));
	    next;
	}
	printf(OUT "%s\n", $l);
    }

    close(OUT);
    rename($htmlout . ".new", $htmlout);
}


#
# Main
#

&Getopts("c:t:");

if (! -f $opt_c) {
    &err("description file (-c file) not readable; $opt_c");
}
&read_desc($opt_c);
if (! -f $opt_t) {
    &err("template file (-t file) not readable: $opt_t");
}
&read_template($opt_t);

&process_data($opt_c);
