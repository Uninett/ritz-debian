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
# read a specially "stylished" xfig file, produce a plot showing
# the interface load in percentage for the ports present in the drawing.
#
# Idea originally borrowed from MRTg's contributed rdlog2 program.
#

use GD;
use CGI;

push(@INC, "%LIBDIR%");

require 'utils.pl';
require 'date.pl';


$border = 10;			# in pixels
$scale = 15;			# fig units / pixel

$type_rect = 10;		# rather arbitrary

# These are the standard fig colors, in "fig notation"

@fig_colors = (0x000000,	# 0 black
	       0x0000ff,	# 1 blue
	       0x00ff00,	# 2 green
	       0x00ffff,	# 3 cyan 
	       0xff0000,	# 4 red 
	       0xff00ff,	# 5 magenta 
	       0xffff00,	# 6 yellow 
	       0xffffff,	# 7 white 
	       0x000090,	# 8 blue4 
	       0x0000b0,	# 9 blue3 
	       0x0000d0,	# 10 blue2 
	       0x87ceff,	# 11 ltblue 
	       0x009000,	# 12 green4 
	       0x00b000,	# 13 green3 
	       0x00d000,	# 14 green2 
	       0x009090,	# 15 cyan4 
	       0x00b0b0,	# 16 cyan3 
	       0x00d0d0,	# 17 cyan2 
	       0x900000,	# 18 red4 
	       0xb00000,	# 19 red3 
	       0xd00000,	# 20 red2 
	       0x900090,	# 21 magenta4 
	       0xb000b0,	# 22 magenta3 
	       0xd000d0,	# 23 magenta2 
	       0x803000,	# 24 brown4 
	       0xa04000,	# 25 brown3 
	       0xc06000,	# 26 brown2 
	       0xff8080,	# 27 pink4 
	       0xffa0a0,	# 28 pink3 
	       0xffc0c0,	# 29 pink2 
	       0xffe0e0,	# 30 pink 
	       0xffd700,	# 31 gold 
	       );


sub add_fig_color {
    my($ix, $cr) = @_;

    $fig_colors[$ix] = $cr;
}

sub fig_head {
    my($fh) = @_;
    my($l, $n, $i);

    $l = <$fh>;
    if ($l =~ /FIG 3.1/) {
	$n = 4;
    } elsif ($l =~ /FIG 3.2/) {
	$n = 8;
    }
    for ($i = 1; $i <= $n; $i++) {
	$l = <$fh>;		# simply discard
    }
}

sub fig_color {
    my(@f) = @_;
    my($cs, $cr);

    $cs = substr($f[2], 1);
    $cr = hex($cs);
    &add_fig_color($f[1], $cr);
}

sub get_pl_coords {
    my($fh, $npts) = @_;
    my($l, @c);
    my(@coords);

    $npts *= 2;
    @coords = ();
    do {
	$l = <$fh>;
	chop($l);
	$l =~ s/^\s*//;
	@c = split(/\s+/, $l);
	$npts -= ($#c + 1);
	@coords = ( @coords, @c );
    } while ($npts > 0);
    return @coords;
}

sub fig_polyline {
    my($fh, $elt, @f) = @_;
    my(@c, $x, $y, $mx, $my);

    $draw[$elt] = 1;		# we assume it'll be drawn, detect
				# "gifarea" or "imgarea" later
    if (defined($parent)) {
	$parent[$elt] = $parent;
	if (defined($polyline[$parent])) {
	    &err("Parent has more than one polyline at line $.");
	}
	$polyline[$parent] = $elt;
    }

    $width[$elt] = $f[3];
    $pen_color[$elt] = $f[4];
    $fill_color[$elt] = $f[5];
    $fill[$elt] = $f[8];
    @c = &get_pl_coords($fh, $f[15]);
    if ($f[1] == 2) {		# rectangle
	$x = &min($c[0], $c[4]);
	$y = &min($c[1], $c[5]);
	$mx = &max($c[0], $c[4]);
	$my = &max($c[1], $c[5]);
	$coords[$elt] = join(' ', $x, $y, $mx, $my);
	$type[$elt] = $type_rect;
    } else {
	$coords[$elt] = join(' ', @c);
    }
}

sub fig_text {
    my($elt, @f) = @_;
    my($txt) = substr($f[13], 0, length($f[13]) - 4);
    my(@a);

    if (defined($parent)) {	# inside a compound, only recognize specials
	if ($txt =~ /gifarea/ ||
	    $txt =~ /imgarea/) { # area of drawing
	    $area_elt = $parent;
	} elsif ($txt =~ /name:/) { # name of port
	    @a = split(/: */, $txt, 2);
	    $name[$parent] = $a[1];
	} elsif ($txt =~ /map:/) { # sub-map
	    @a = split(/: */, $txt, 2);
	    $map[$parent] = $a[1];
	} elsif ($txt =~ /urlc:/) { # URL component
	    @a = split(/: */, $txt, 2);
	    $urlc[$parent] = $a[1];
	} elsif ($txt =~ /lw:/) { # line width designator
	    @a = split(/: */, $txt, 2);
	    $lw[$parent] = $a[1];
	    $lw_text_elt[$a[1]] = $elt;
	}
    } else {			# outside a compound, possibly
				# ordinary text to be drawn
	if ($txt =~ /color:/) { # color specification
	    @a = split(/:/, $txt);
	    $load_color[$a[1]] = $f[2];
	    $color_elt[$a[1]] = $elt;
	} else {
	    $pen_color[$elt] = $f[2];
	    $text[$elt] = $txt;
	    $draw[$elt] = 1;
	}
    }
    $x[$elt] = $f[11];
    $y[$elt] = $f[12];
    $angle[$elt] = $f[7];
    if ($angle[$elt] < 1) {
	$y[$elt] -= 150;
    } else {
	$x[$elt] -= 150;
    }
    $parent[$elt] = $parent;
}

sub fig_ellipsis {
    my($elt, @f) = @_;

    $draw[$elt] = 1;
    if (defined($parent)) {
	&err("Ellipsis in a compound at line $. does not make sense");
    }
    $width[$elt] = $f[3];
    $pen_color[$elt] = $f[4];
    $fill_color[$elt] = $f[5];
    $fill[$elt] = $f[8];
    $x[$elt] = $f[12];
    $y[$elt] = $f[13];
    $radius_x[$elt] = $f[14];
    $radius_y[$elt] = $f[15];
}

sub fig_compound {
    my($elt) = @_;

    return $elt;
}

sub read_fig {
    my($fh) = @_;
    my(@f, $n);

    &fig_head($fh);
    $n = 0;
    while(<$fh>) {
	chop;
	@f = split;
	$type[$n] = $f[0];
	if	($f[0] == 0) {	# color
	    &fig_color(@f);
	} elsif ($f[0] == 1) {	# ellipsis/circle
	    &fig_ellipsis($n++, @f);
	} elsif ($f[0] == 2) {	# polyline
	    &fig_polyline($fh, $n++, @f);
	} elsif ($f[0] == 4) {	# text
	    @f = split(/\s+/, $_, 14);
	    &fig_text($n++, @f);
	} elsif ($f[0] == 6) {	# compound
	    if (!defined($parent)) {
		$parent = &fig_compound($n++);
	    } else {
		&err("Nested compound in fig file at $.");
	    }
	} elsif ($f[0] == -6) {	# end-compound
	    undef($parent);
	}			# ignore the rest
    }
    return ($n - 1);		# maximum element number
}

#
# GD-related stuff
#

sub fig_to_rgb {
    my($fc) = @_;
    my($red, $green, $blue);

    $red = ($fc >> 16) & 0xff;
    $green = ($fc >> 8) & 0xff;
    $blue = $fc & 0xff;
    return ($red, $green, $blue);
}

sub find_rgb_color {
    my($r, $g, $b, $img) = @_;
    my($c);

    if (($c = $img->colorExact($r, $g, $b)) == -1) {
	if (($c = $img->colorAllocate($r, $g, $b)) == -1) {
	    $c = $img->colorClosest($r, $g, $b);
	}
    }
    return $c;
}

sub find_color {
    my($fi, $img) = @_;
    my($c, $fc);

    $fc = $fig_colors[$fi];
    return &find_rgb_color(&fig_to_rgb($fc), $img);
}

# Translate (and scale) coordinates, list of alternating x,y

sub xlc {
    my(@fcs) = @_;
    my(@xlcs, $c);

    while($#fcs >= 0) {
	push(@xlcs, (((shift(@fcs)-$xoff)/$scale)+$border));
	push(@xlcs, (((shift(@fcs)-$yoff)/$scale)+$border));
    }

    return (@xlcs);
}

# Only do scaling of coordinates (radii and other relative distances)

sub scale {
    my(@l) = @_;
    my(@nl);
    
    while($#l >= 0) {
	push(@nl, (shift(@l) / $scale));
    }
    return (@nl);
}

sub draw_ellipsis {
    my($img, $e) = @_;
    my($b, $c);

    if ($width[$e] != 1) {
	$b = &get_fig_brush($width[$e], $pen_color[$e]);
	$img->setBrush($b);
	$c = GD::gdBrushed;
    } else {
	$c = &find_color($pen_color[$e], $img);
    }

    $img->arc(&xlc($x[$e], $y[$e]),
	      &scale($radius_x[$e]*2,
		     $radius_y[$e]*2),
	      0, 360, $c);

    if ($fill[$e] != -1) {
	$img->fill(&xlc($x[$e], $y[$e]),
		   &find_color($fill_color[$e], $img));
    }
}

sub get_fig_brush {
    my($lw, $fi) = @_;
    my($fc, $r, $g, $b);
    my($brush, $c);
    
    $brush = new GD::Image($lw,$lw);
    &find_color($fi, $brush);	# should allocate background color
    return $brush;
}

sub get_lw_colored_brush {
    my($lw, $r, $g, $b) = @_;
    my($brush);

    $brush = new GD::Image($lw,$lw);
    $brush->colorAllocate($r,$g,$b); # background, first color
    return $brush;
}

sub get_lw_brush {
    my($lw) = @_;
    
    return &get_lw_colored_brush($lw, 0,0,0); # black
}

# Draw a polyline or return an imagemap substring.

sub draw_polyline {
    my($img, $e) = @_;
    my(@c, $parent, $c, $b, $poly, $mapcomp, $url, $alt);
    
    @c = split(/ /, $coords[$e]);
    if (defined($parent = $parent[$e])) {
	if (defined($name[$parent])) {
	    $b = &get_name_brush($name[$parent]);
	}
	if (defined($lw[$parent])) {
	    $b = &get_lw_brush($lw[$parent]);
	}

	if (defined($urlc[$parent])) { # make imagemap string & return
	    $url = &get_url($urlc[$parent]);
	    $alt = &get_alt($urlc[$parent]);

	    $mapcomp = sprintf("<area shape=poly coords=\"");
	    while($#c > 0) {
		$mapcomp .= sprintf("%d,%d,", &xlc(shift(@c),shift(@c)));
	    }
	    chop($mapcomp);	# remove final ','
	    $mapcomp .= sprintf("\"\n\thref=\"%s\"\n\talt=\"%s\">\n",
			       $url, $alt);
	    return($mapcomp);
	}

	if (! defined($b)) { return; }

	$img->setBrush($b);
	$c = GD::gdBrushed;
    } else {
	if ($width[$e] != 1) {
	    $b = &get_fig_brush($width[$e], $pen_color[$e]);
	    $img->setBrush($b);
	    $c = GD::gdBrushed;
	} else {
	    $c = &find_color($pen_color[$e], $img);
	}
    }
    $poly = new GD::Polygon;
    while($#c > 0) {
	$x = shift(@c);
	$y = shift(@c);
	$poly->addPt(&xlc($x,$y));
    }
    $img->polygon($poly, $c);
    return undef;
}

# Draw a rectangle and return undef
# or return an image map component string

sub draw_rect {
    my($img, $e) = @_;
    my(@c, $parent, $url, $alt, $mc);

    @c = split(/ /, $coords[$e]);
    if (defined($parent = $parent[$e])) {
	if (($parent == $area_elt) ||
	    (defined($map[$parent])))
	{
	    return;
	}
	if (defined($urlc[$parent])) {
	    $url = &get_url($urlc[$parent]);
	    $alt = &get_alt($urlc[$parent]);
	    $mc = sprintf("<area shape=rect coords=\"%s\"\n",
			  join(",", &xlc(@c)));
	    $mc .= sprintf("\thref=\"%s\"\n", $url);
	    $mc .= sprintf("\talt=\"%s\">\n", $alt);
	    return($mc);
	}

    }

    if ($fill[$e] != -1) {
	$img->filledRectangle(&xlc(@c),
			      &find_color($fill_color[$e], $img));
    }
    $img->rectangle(&xlc(@c), &find_color($pen_color[$e], $img));
    return undef;
}

sub draw_text {
    my($img, $e) = @_;
    my($c);
    
    $c = &find_color($pen_color[$e], $img);
    if ($angle[$e] == 0) {
	$img->string(gdSmallFont, &xlc($x[$e], $y[$e]), $text[$e], $c);
    } else {
	$img->stringUp(gdSmallFont, &xlc($x[$e], $y[$e]), $text[$e], $c);
    }
}

sub get_area {
    my($w, $h);
    my($e, @c, $c);
    
    if (!defined($area_elt)) {
	&err("No \"gifarea\" or \"imgarea\" tag found");
    }
    if (!defined($e = $polyline[$area_elt])) {
	&err("No polyline in \"gifarea\" or \"imgarea\" tagged compound");
    }
    @c = split(/ /, $coords[$e]);
    if ($type[$e] != $type_rect) {
	&err("Polyline for \"gifarea\" or \"imgarea\" is not a rectangle");
    }
    $w = $c[2] - $c[0];
    $h = $c[3] - $c[1];
    $xoff = $c[0];
    $yoff = $c[1];
    $c = $pen_color[$e];
    return (&scale($w, $h), $c);
}

sub draw_border {
    my($img, $w, $h) = @_;
    my($light, $dark, $b);
    
    $light = &find_rgb_color(194, 194, 194, $img);
    $dark =  &find_rgb_color(100, 100, 100, $img);

    $b = $border;
    $img->line($b,$b,$w-$b-1,$b, $light);
    $img->line($b+1,$b+1,$w-$b-2,$b+1, $light);
    $img->line($b,$b,$b,$h-$b-1, $light);
    $img->line($b+1,$b+1,$b+1,$h-$b-2, $light);
    $img->line($w-$b-1,$b,$w-$b-1,$h-$b-1, $dark);
    $img->line($b,$h-$b-1,$w-$b-1,$h-$b-1, $dark);
    $img->line($w-$b-2,$b+1,$w-$b-2,$h-$b-2, $dark);
    $img->line($b+1,$h-$b-2,$w-$b-2,$h-$b-2, $dark);
}

sub legends {
    my($img) = @_;
    my($e, $i, $c);

    $c = &find_color(0, $img);	# black
    for ($i = 0; $i <= 9; $i++) { # colors, must be 10
	$e = $color_elt[$i];
	$img->string(gdSmallFont, &xlc($x[$e], $y[$e]),
		     sprintf("%d - %d%%", $i*10, ($i+1)*10),
		     $c);
    }
    for ($i = 1; defined($high[$i]); $i++) {
	if (!defined($e = $lw_text_elt[$i])) { next; }
	$img->string(gdSmallFont, &xlc($x[$e], $y[$e]),
		     $lw_text[$i], $c);
    }
}

sub draw_title {
    my($img, $w, $h, $title) = @_;
    my($len, $pw, $x, $y, $c);
    
    $len = length($title);
    $pw = $len * 6;		# small font is apparenty 6pix wide
    $x = ($w / 2) - ($pw / 2);	# center text

    $c = &find_color(0, $img);	# black
    $img->string(gdSmallFont, $x, 0, $title, $c);
}

sub draw_img {
    my($elts, $title) = @_;
    my($e, $img, $w, $h, $bg, $c, $mc, $mapcomps);

    ($w, $h, $c) = &get_area();

    $w += $border*2;		# for border & zoom areas
    $h += $border*2;
    $img = new GD::Image($w, $h);
    # The color allocated first is the background
    $bg = &find_color($c, $img);

    &draw_border($img, $w, $h);

    # $img->interlaced(1);

    $mapcomps = "";
    for ($e = 0; $e <= $elts; $e++) {
	if (!defined($draw[$e])) {
	    next;
	}
	if 	($type[$e] == 1) { # ellipsis/circle
	    &draw_ellipsis($img, $e);
	} elsif ($type[$e] == 2) { # polyline, possibly a link to be colored
	    $mc = &draw_polyline($img, $e);
	    if (defined($mc)) {
		$mapcomps .= $mc;
	    }
	} elsif ($type[$e] == 4) { # text
	    &draw_text($img, $e);
	} elsif ($type[$e] == $type_rect) { # simple rectangle
	    $mc = &draw_rect($img, $e);
	    if (defined($mc)) {
		$mapcomps .= $mc;
	    }
	}
    }
    &legends($img);
    &draw_title($img, $w, $h, $title);
    return($img, $mapcomps);
}

#
# Test rig only, this will be filled out later with a HTML wrapper etc.
#

sub read_ranges {
    my($fh) = @_;
    my(@f, $n);

    for ($n = 1; <$fh>; $n++) {
	@f = split(/\s+/, $_, 2);
	$high[$n] = $f[0];
	$lw_text[$n] = $f[1];
    }
}

sub get_width {
    my($speed) = @_;
    my($n);

    for ($n = 1; defined($high[$n]); $n++) {
	if ($speed < $high[$n]) {
	    return($n);
	}
    }
    return ($n-1);		# max
}

sub get_fig_colorix {
    my($load) = @_;
    my($ix);
    
    $ix = int($load/10);
    if ($ix > 9) { $ix = 9; }
    if ($ix < 0) { $ix = 0; }
    return $load_color[$ix];
}

sub get_name_brush {
    my($name) = @_;
    my($val, $speed, $c, $w);

    # Placeholder for now, later this should pick brush width
    # based on speed and color based on %load for the named port.
    
    if ($name =~ /(.*)\/i/) {
	$name = $1;
	$val = $in_load{$name};
    } else {
	$val = $out_load{$name};
    }

    if (!defined($val)) { return undef; }

    $w = &get_width($speed{$name});
    $fi = &get_fig_colorix($val);

    return &get_fig_brush($w, $fi);
}

# Read in base data, return number of records read.

sub read_data {
    my($fh) = @_;
    my(@f, $nr);

    $nr = 0;
    while(<$fh>) {
	chop;
	@f = split;
	$in_load{$f[0]} = $f[1];
	$out_load{$f[0]} = $f[2];
	$speed{$f[0]} = $f[3];
	$nr++;
    }
    return $nr;
}

sub img_names {
    my($m, $dsp, $t, $s) = @_;
    my($b);

    $b = sprintf("lm.%s.%s.%s.%s.png", $m, $dsp, $t, $s);
    return(
	   sprintf("%HTMLPFX%/imgs/%s", $b),
	   sprintf("%s/imgs/%s", "%HTMLDIR%", $b)
	   );
}

sub get_title {
    my($m, $dsp, $t, $s) = @_;

    return sprintf("Map %s for %s showing %s %s",
		   $m, $dsp, $s, $t);
}

# By popular demand, show the load graphs directly in kbit/s, not
# as percentage of link capacity.

%map_type = ("traffic" => "traffic-kbit",
	     );

sub save_url_comps {
    my($dsp, $type) = @_;

    $datespec = $dsp;
    if (!defined($graph_type = $map_type{$type})) {
	$graph_type = $type;
    }
}

sub get_url {
    my($urlc) = @_;

    return sprintf("%splot-all/%s,%s,hr,%s",
		   $pfx, $urlc, $datespec, $graph_type);
}

sub get_alt {
    my($urlc) = @_;

    return sprintf("[%s %s plot]", $urlc, $graph_type);
}

sub err {
    my($msg) = @_;

    printf("<h2>%s</h2>\n", $msg);
    print $doc->end_html;
    print "\n";
    exit(1);
}

sub getargs {
    my($exp, $map, $dsp, $type, $select);

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

    $ourname = sprintf("%sload-map", $pfx);

    ($map, $dsp, $type, $select) = split(/\s*,\s*/, $query);

    if (!defined($dsp) || $dsp eq "") {
	$dsp = &yesterday_spec();	# default is to show for previous day
	$exp = &secs_to_expiry("day");
    } else {
	$exp = 30*24*60*60;		# one month, really "eternally"
    }

    return($exp, $map, $dsp, $type, $select);
}

sub start_doc {
    my($exp, @args) = @_;
    my($title);
    
    # Emit a sensible Expires: header
    print $doc->header(-type => "text/html",
		       -expires => sprintf("+%ds", $exp));

    $title = &get_title(@args);
    print $doc->start_html(-title=>$title);
}

sub get_data {
    my($dsp, $type, $select) = @_;
    my($nr);
    
    # Get base data
    $cmd = sprintf("%s/bin/sel-report -d %s -t %s -s %s",
		   "%TOPDIR%", $dsp, $type, $select);

    open(DATA, "$cmd |");
    $nr = &read_data(DATA);
    if ($nr == 0) {
	&err("No data found for requested time");
    }
    close(DATA);
}

sub read_map {
    my($map) = @_;
    my($elts, $fig);
    
    # Read map file in fig format
    $fig = "%MAPDIR%/" . $map . ".fig";
    open(FIG, $fig) || &err("Could not open map file for $map: $!");
    $elts = &read_fig(FIG);
    close(FIG);
    return $elts;
}

sub read_lw_data {
    my($map) = @_;
    my($lwf);
    
    # Read in range data
    $lwf = "%MAPDIR%/" . $map . ".rng";
    if (! -f $lwf) {
	$lwf = "%MAPDIR%/default.rng";
	if (! -f $lwf) {
	    &err("Could neither get line-width file for $map nor defaults");
	}
    }
    open(RNG, $lwf) || &err("Could not open range file for $map: $!");
    &read_ranges(RNG);
    close(RNG);
}

sub map_ref {
    my($map, $dsp, $type, $select) = @_;

    return
	sprintf("%s/%s,%s,%s,%s", $ourname,
		$map, $dsp, $type, $select);
}

sub map_alt {
    my($map, $dsp, $type, $select) = @_;

    return
	sprintf("[%s %s/%s map for %s]",
		$map, $type, $select, $dsp);

}

sub nx_coords {
    my($w, $h) = @_;

    return
	sprintf("%d,%d,%d,%d", $w-$border, 0, $w, $h);
}

sub pr_coords {
    my($w, $h) = @_;

    return
	sprintf("%d,%d,%d,%d", 0, 0, $border, $h);
}

sub add_zoom_areas {
    my($map, $dsp, $type, $select) = @_;
    my($w, $h, $c, $pr_dsp, $nx_dsp, $pr_base_tm, $nx_base_tm, $ndays);
    my($pr_ex, $nx_ex);

    ($w, $h, $c) = &get_area();

    $w += $border*2;		# for border & zoom areas
    $h += $border*2;
    
    # Provide pointers to next and previous period
    # with "same" parameters

    $pr_dsp = &previous_datespec($dsp);
    $nx_dsp = &next_datespec($dsp);

    if (defined($pr_dsp) && defined($nx_dsp)) {
	($pr_base_tm, $ndays) = &decode_datespec($pr_dsp);
	($nx_base_tm, $ndays) = &decode_datespec($nx_dsp);

	# How far back do we have data available
	$pr_ex = ($pr_base_tm >= $origin);
	# Make sure we are not trying to see into the future
	# (or trying to do "today")
	$nx_ex = ($nx_base_tm < (time - 24*60*60));
	
	if ($pr_ex) {
	    printf("<area shape=rect coords=\"%s\"\n", &pr_coords($w, $h));
	    printf("\thref=\"%s\"\n", &map_ref($map, $pr_dsp, $type, $select));
	    printf("\talt=\"%s\">\n", &map_alt($map, $pr_dsp, $type, $select));
	}
	if ($nx_ex) {
	    printf("<area shape=rect coords=\"%s\"\n", &nx_coords($w, $h));
	    printf("\thref=\"%s\"\n", &map_ref($map, $nx_dsp, $type, $select));
	    printf("\talt=\"%s\">\n", &map_alt($map, $pr_dsp, $type, $select));
	}
    }
}

sub add_help_ptr {

    printf("<p>A short <a href=\"%s\">explanation</a>",
	   sprintf("%s../stats/map-doc.html", $pfx));
    printf(" of the map is available\n");
}

sub produce_map {
    my($exp, $map, $dsp, $type, $select) = @_;
    my($elts, $refname, $file, $img, $title, $mapcomps);

    &save_url_comps($dsp, $type);
    &get_data($dsp, $type, $select);
    $elts = &read_map($map);
    &read_lw_data($map);

    $title = &get_title($map, $dsp, $type, $select);

    # Produce image file (PNG)
    ($refname, $file) = &img_names($map, $dsp, $type, $select);

    ($img, $mapcomps) = &draw_img($elts, $title);
    open(OUT, ">$file") ||
	&err("Could not open PNG file $file for $refname for write: $!");
    print OUT $img->png;
    close(OUT);

    # Now produce normal document
    printf("<h2>%s</h2>\n", $title);

    printf("<a href=\"%s\">\n\t<img src=\"%s\" ", $refname, $refname);
    printf("\n\talt=\"[PNG image]\"\n\tusemap=\"#mymap\">\n</a>\n");

    printf("<map name=\"mymap\">\n");
    printf("%s", $mapcomps);
    &add_zoom_areas($map, $dsp, $type, $select);
    printf("</map>\n");
    &add_help_ptr();

    print $doc->end_html;
    print "\n";
}

#
# Main
#

$doc = new CGI;

umask 0;

($exp, @args) = &getargs();
&start_doc($exp, @args);	# so that we can emit HTML,
				# be it error messages
				# or the real document
# Validate arguments
if (defined($ai = &invalid_arg("[-A-Za-z0-9_.]*", @args))) {
    &err(sprintf("Invalid argument: %s", $args[$ai]));
}

&produce_map($exp, @args);
