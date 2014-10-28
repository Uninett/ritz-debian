#!%PERL%
#
# $Id$
#

# Copyright (c) 2001,
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
# Read a specially stylished tgif file, produce a drawing showing
# the interface load in percentage for the ports present in the drawing.
#
# For now, just input drawing and output interpreted file.
#

use GD;
use CGI;

push(@INC, "%LIBDIR%");

require 'reverse.pl';
require 'utils.pl';
require 'date.pl';

push(@INC, "%CONFDIR%");

require "zino-config.pl";

if (!defined($load_now)) {
    $load_now = "%TOPDIR%" . "/reports/load-now.txt";
}

use POSIX qw(strftime);


$border = 10;			# in pixels
$scale = 1.5;
$touch_len = 5;			# sensitive area around lines


sub tgif_head {
    my($fh) = @_;
    my(@f);

    $_ = <$fh>; chop;
    if ($_ !~ /^%TGIF/) {
	&err("Not a tgif file.\n");
    }
    $_ = <$fh>; chop;
    @f = split(/[,\(]+/);
    if ($f[1] != 1 && $f[2] < 37) {
	&err("Too old version of tgif.\n");
    }
}


sub tgif_color_info {
    my($fh, @f) = @_;
    my($nc) = $f[1];
    my($cname, $r, $g, $b, @rest);
    
    for ($n = 0; $n < $nc; $n++) {
	$_ = <$fh>; chop;
	$_ =~ s/^\s+//;
	($cname, $r, $g, $b, @rest) = split(/[, ]+/);
	$cname =~ s/\"//g;

	$red{$cname}   = $r / 256;
	$green{$cname} = $g / 256;
	$blue{$cname}  = $b / 256;
    }
    $_ = <$fh>;
}

sub tgif_minilines {
    my($fh, $elt, $show, $lines, @f) = @_;
    my($n, @lines);

    if (/^minilines/ && $lines > 0) {
	for ($n = 0; $n < $lines; $n++) {
	    $_ = <$fh>;
	    if (/^mini_line/) {
		$_ = <$fh>;
		if (/^str_block/) {
		    $_ = <$fh>;
		    if (/^str_seg/) {
			$_ = <$fh>;
			@f = split(/\"/);
			push(@lines, $f[1]);
		    }
		}
	    } else {
		&warn(sprintf("mini_line not found at line %s.\n", $.) .
		      sprintf("line: %s", $_));
	    }
	    $_ = <$fh>;
	}
	if ($show) {
	    $text[$elt] = join("\n", @lines);
	    $type[$elt] = "text";
	    $elt++;
	}
    } else {
	&warn(sprintf("minilines not found, $lines expected at line %s.\n",
		      $.) .
	      sprintf("line: %s\n", $_));
    }
    $_ = <$fh>;
    return $elt;
}

sub tgif_text {
    my($fh, $elt, $show, @f) = @_;
    my($n, $lines);

    if (/^text/) {
	$x[$elt] = $f[2];
	$y[$elt] = $f[3];
	$lines = $f[4];
	$_ = <$fh>; chop; @f = split(/[,\(]+/);
	if (/^\s/) {		# uh-oh; transformed text -- ignore
	    $_ = <$fh>; chop; @f = split(/[,\(]+/);
	}
	$elt = &tgif_minilines($fh, $elt, $show, $lines, @f);
    }
    return $elt;
}

sub tgif_attr {
    my($fh, $elt, @f) = @_;
    my($lw_seen, $oelt);

    if (/^attr/) {
	my($n) = $f[1];
	$n =~ s/[\"=]+//g;
	my($v) = $f[2];
	$v =~ s/[\"]+//g;
	if ($n eq "name") {
	    if ($v eq "area") {
		$hide[$elt] = 1;
		$area_elt = $elt;
	    }
	    $name[$elt] = $v;
	} elsif ($n eq "color") {
	    $load_color[$v] = $fill_color[$elt];
	    $color_elt[$v] = $elt;
	} elsif ($n eq "lowlim") {
	    $lowlimit[$elt] = $v;
	    $limits_specified = 1;
	} elsif ($v eq "nosplit") {
	    $nosplit[$elt] = 1;
	} elsif ($n eq "mapref") {
	    $mapref[$elt] = $v;
	} elsif ($n eq "mapalt") {
	    $mapalt[$elt] = $v;
	} elsif ($n eq "lw") {
	    $lw_seen = 1;
	} else {
	    &warn(sprintf("Unknown attr: '%s=%s'\n", $n, $v));
	}
	$_ = <$fh>;
	@f = split(/[,\(]+/);
	$oelt = $elt;
	$elt = &tgif_text($fh, $elt, 0, @f);
	# Be a bit incestuous in relying on the fact
	# that tgif_text() stores the text element coords in x and y.
	if ($lw_seen) {
	    $lw_text_elt[$v] = $oelt;
	}
    }
    return $elt;
}


sub tgif_attrlist {
    my($fh, $elt) = @_;
    my(@f);

    while(<$fh>) {
	chop;
	if (/^\]\)/) { return $elt; }
	@f = split(/[, \(]+/);
	$elt = &tgif_attr($fh, $elt, @f);
    }
    return $elt;
}

sub tgif_box {
    my($fh, $elt, @f) = @_;
    my($c) = $f[1];

    $c =~ s/\'//g;
    $pen_color[$elt] = $c;
    $fill_color[$elt] = $c;
    $fill[$elt] = $f[7];
    $coords[$elt] = join(' ', @f[3 .. 6]);
    $width[$elt] = $f[8];
    $type[$elt] = "rectangle";

    $elt = &tgif_attrlist($fh, $elt);

    $elt++;
    return $elt;
}

sub tgif_polygon {
    my($fh, $elt, @f) = @_;
    my($nvs) = $f[3];		# Number of vertices
    my($c) = $f[1];		# Pen color
    my($vc);			# Vertice count in current block

    $c =~ s/\'//g;
    $pen_color[$elt] = $c;
    $coords[$elt] = "";
    while ($nvs > 0) {
	$vc = ($nvs > 8) ? 8 : $nvs;
	$_ = <$fh>;
	$_ =~ s/^\s+//g;
	@f = split(/[,\]]+/);
	$coords[$elt] .= " " . join(' ', @f[0 .. ($vc*2)-1]);
	$nvs -= $vc;
    }
    $coords[$elt] =~ s/^\s//;
    $width[$elt] = $f[($vc*2)+1];
    $type[$elt] = "polygon";
    $fill[$elt] = $f[$vc*2];

    $_ = <$fh>;
    $elt = &tgif_attrlist($fh, $elt);

    $elt++;
    return $elt;
}

sub tgif_poly {
    my($fh, $elt, @f) = @_;
    my($nvs) = $f[3];
    my($vc);
    my($c) = $f[1];

    $c =~ s/\'//g;
    $pen_color[$elt] = $c;
    $coords[$elt] = "";
    while ($nvs > 0) {
	$vc = ($nvs > 8) ? 8 : $nvs;
	$_ = <$fh>;
	$_ =~ s/\s+//g;
	@f = split(/[,\]]+/);
	$coords[$elt] .= " " . join(' ', @f[0 .. ($vc*2)-1]);
	$nvs -= $vc;
    }
    $coords[$elt] =~ s/^\s//;
    $width[$elt] = $f[($vc*2)+1];
    $type[$elt] = "polyline";

    $_ = <$fh>;
    $_ = <$fh>;
    $elt = &tgif_attrlist($fh, $elt);

    $elt++;
    return $elt;
}

sub tgif_oval {
    my($fh, $elt, @f) = @_;
    my($ltx, $lty, $brx, $bry) = @f[3 .. 6];
    my($cx, $cy, $rx, $ry);

    $rx = ($brx - $ltx) / 2;
    $ry = ($bry - $lty) / 2;
    $cx = $ltx + $rx;
    $cy = $lty + $ry;

    $type[$elt] = "ellipsis";
    $cx[$elt] = $cx;
    $cy[$elt] = $cy;
    $radius_x[$elt] = $rx;
    $radius_y[$elt] = $ry;
    $width[$elt] = $f[8];
    $elt = &tgif_attrlist($fh, $elt);

    $elt++;
    return $elt;
}

sub tgif_group {
    my($fh, $elt, @f) = @_;

    $elt = &tgif_objlist($fh, $elt, @f);
    $_ = <$fh>;
    $elt = &tgif_attrlist($fh, $elt);
    return $elt;
}

# One-line directives we ignore

%ignore = ("unit" => 1,
	   "script_frac" => 1,
	   "fg_bg_colors" => 1,
	   "page" => 1,
	   "dont_reencode" => 1,
	   "objshadow_info" => 1,
	   "rotate_pivot" => 1,
	   "spline_tightness" => 1,
       );

sub tgif_obj {
    my($fh, $elt, @f) = @_;

    if ($f[0] eq "color_info") {
	&tgif_color_info($fh, @f);
    } elsif ($f[0] eq "box") {
	$elt = &tgif_box($fh, $elt, @f);
    } elsif ($f[0] eq "text") {
	$elt = &tgif_text($fh, $elt, 1, @f);
    } elsif ($f[0] eq "poly") {
	$elt = &tgif_poly($fh, $elt, @f);
    } elsif ($f[0] eq "polygon") {
	$elt = &tgif_polygon($fh, $elt, @f);
    } elsif ($f[0] eq "oval") {
	$elt = &tgif_oval($fh, $elt, @f);
    } elsif ($f[0] eq "group") {
	$elt = &tgif_group($fh, $elt, @f);
    } elsif (defined($ignore{$f[0]})) {
	return $elt;
    } else {
	&warn(sprintf("TGIF Line %s Skipped: %s\n", $., $_));
    }
    return $elt;
}

sub tgif_objlist {
    my($fh, $elt, @f) = @_;

    do {
	$_ = <$fh>; chop; @f = split(/[,\(\) ]+/);
	$elt = &tgif_obj($fh, $elt, @f);
    } while ($_ =~ /,$/);
    return $elt;
}

sub setup_color_limits {
    my($c, $elt);

    for($c = 0; $c <= $#load_color; $c++) {
	$elt = $color_elt[$c];
	$load_limit[$c] = $lowlimit[$elt];
    }
}

sub read_tgif {
    my($fh) = @_;
    my(@f, $elt);

    &tgif_head($fh);
    $elt = 0;
    while(<$fh>) {
	if (/^%/) { next; }
	chop;
	@f = split(/[,\(\) ]+/);
	$elt = &tgif_obj($fh, $elt, @f);
    }
    if (defined($limits_specified)) {
	&setup_color_limits();
    }
    return $elt;
}

#
#
#

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
    my($cname, $img) = @_;
    our(%red, %green, %blue);

    if (!defined($red{$cname})) {
	my $fc = substr($cname, 0, 1);
        my $r = substr($cname, 1);
	my $c = uc($fc) . $r;
	if (defined($red{$c})) {
		$cname = $c;
	} else {
		warn("Unknown color: $cname");
	}
    }

    return &find_rgb_color($red{$cname},
			   $green{$cname},
			   $blue{$cname},
			   $img);
}


# Translate (and scale) coordinates, list of alternating x,y pairs

sub xlc {
    my(@fcs) = @_;
    my(@xlcs, $c);

    while($#fcs >= 0) {
	push(@xlcs, (((shift(@fcs)-$xoff)/$scale)+$border));
	push(@xlcs, (((shift(@fcs)-$yoff)/$scale)+$border));
    }

    return (@xlcs);
}

# Scale a set of relative distances

sub scale {
    my(@l) = @_;
    my(@nl);
    
    while($#l >= 0) {
	push(@nl, (shift(@l) / $scale));
    }
    return (@nl);
}

# Get drawing area

sub get_area {
    my($w, $h, $e, @c, $c);

    if (!defined($area_elt)) {
	&err("No \"area\" tag found");
    }
    $e = $area_elt;
    if ($type[$e] ne "rectangle") {
	&err("Object type for \"area\" object is not rectangle");
    }
    @c = split(/ /, $coords[$e]);
    $w = $c[2] - $c[0];
    $h = $c[3] - $c[1];
    $xoff = $c[0];
    $yoff = $c[1];
    $c = "white";
    return(&scale($w, $h), $c);
}

#
# GD-specific code
#

sub get_brush {
    my($img, $lw, $cname) = @_;
    my($c);
    
    $brush = new GD::Image($lw,$lw);
    &find_color($cname, $brush); # should allocate background color
    $img->setBrush($brush);
    $c = GD::gdBrushed;
    return $c;
}

sub draw_rectangle {
    my($img, $e) = @_;
    my(@c);

    @c = split(/ /, $coords[$e]);

    if ($fill[$e] != 0) {
	$img->filledRectangle(&xlc(@c),
			      &find_color($fill_color[$e], $img));
    }
    $img->rectangle(&xlc(@c), &find_color($pen_color[$e], $img));
}

sub line_length {
    my($x1, $y1, $x2, $y2) = @_;
    my($ss);
    
    $ss = ($x2-$x1)**2 + ($y2-$y1)**2;
    return sqrt($ss);
}

sub polyline_length {
    my(@c) = @_;
    my($nc) = $#c+1;
    my($pll) = 0;
    
    while ($#c > 1) {
	$pll += &line_length(@c[0..3]);
	shift(@c); shift(@c);
    }
    return $pll;
}

sub line_seg_rel {
    my($len, $x1, $y1, $dx, $dy) = @_;
    my($ll, $xn, $yn);

    $ll = &line_length($x1, $y1, $x1+$dx, $y1+$dy);
    if ($ll == 0) {
	return($x1, $x2);
    }
    $xn = $x1 + $dx*$len/$ll;
    $yn = $y1 + $dy*$len/$ll;
    
    return($xn, $yn);
}

sub line_seg {
    my($len, $x1, $y1, $x2, $y2) = @_;

    return &line_seg_rel($len, $x1, $y1, $x2-$x1, $y2-$y1);
}

sub first_half_polyline {
    my(@c) = @_;
    my(@nc);
    my($pll) = &polyline_length(@c);
    my($tl) = 0;
    my($l);

    while($tl < $pll / 2) {
	push(@nc, @c[0..1]);
	$l = &line_length(@c[0..3]);
	if ($tl + $l >= $pll / 2) {
	    push(@nc, &line_seg($pll / 2 - $tl, @c));
	    return @nc;
	}
	$tl += $l;
	shift(@c); shift(@c);
    }
}

sub last_half_polyline {
    my(@c) = @_;
    my(@nc, @fh, $n, $ns);

    @fh = &first_half_polyline(@c);
    $ns = $#fh-1;
    for ($n = 0; $n < $ns; $n++) {
	shift(@fh); shift(@c);
    }
    push(@nc, @fh);
    push(@nc, @c);
    return @nc;
}

sub draw_polyline_1 {
    my($img, $c, @c) = @_;
    my(@oc, $x, $y, $xs, $ys);
    my($poly);

    @oc = @c;

    $poly = new GD::Polygon;
    while($#c > 0) {
	$x = shift(@c);
	$y = shift(@c);
	$poly->addPt(&xlc($x,$y));
    }
    if ($#oc > 3) {		# if more than 2 points
	$xs = $oc[0];
	$ys = $oc[1];
	if ($xs != $x && $ys != $y) {
	    # trace back to emulate polyline (not a closed polygon...)
	    pop(@oc); pop(@oc);
	    while($#oc > 0) {
		$y = pop(@oc);
		$x = pop(@oc);
		$poly->addPt(&xlc($x,$y));
	    }
	}
    }
    $img->polygon($poly, $c);
}

# Note: $brush must be global; otherwise left on stack
# and causes problems when we unwind from draw_color later on

sub draw_color {
    my($img, $e, $cname) = @_;
    my($c);

    if ($width[$e] != 1) {
	$c = &get_brush($img, $width[$e], $cname);
    } else {
	$c = &find_color($cname, $img);
    }
    return $c;
}

sub draw_polyline {
    my($img, $e) = @_;
    my(@c, @fh, @lh, @ef, @el);

    @c = split(/ /, $coords[$e]);

    if (defined($name[$e])) {
	if (defined($nosplit[$e])) {
	    &draw_polyline_1($img, &get_name_brush($img, $name[$e]), @c);

#	    @ef = &enclose_polyline(@c);
#	    &draw_polygon_1($img, &draw_color($img, $e, "black"), @ef);
	} else {
	    @fh = &first_half_polyline(@c);
	    @lh = &last_half_polyline(@c);

	    &draw_polyline_1($img,
			     &get_name_brush($img,
					     $name[$e]),
			     @fh);
	    &draw_polyline_1($img,
			     &get_name_brush($img,
					     &rev_name($name[$e])),
			     @lh);

#	    &draw_polyline_1($img, &draw_color($img, $e, "red"), @fh);
#	    &draw_polyline_1($img, &draw_color($img, $e, "green"), @lh);

#	    @ef = &enclose_polyline(@fh);
#	    @el = &enclose_polyline(@lh);
#	    &draw_polygon_1($img, &draw_color($img, $e, "black"), @ef);
#	    &draw_polygon_1($img, &draw_color($img, $e, "black"), @el);
	}
    } else {
	&draw_polyline_1($img, &draw_color($img, $e, "black"), @c);
    }
}

sub draw_text {
    my($img, $e) = @_;
    my(@lines, $x, $y);

    $c = &find_color("black", $img);
    @lines = split(/\n/, $text[$e]);
    $x = $x[$e];
    $y = $y[$e];
    foreach $l (@lines) {
	$img->string(gdSmallFont, &xlc($x, $y), $l, $c);
	$y += 15;
    }
}

sub draw_polygon_1 {
    my($img, $c, @c) = @_;
    my($x, $y);

    $poly = new GD::Polygon;
    while($#c > 0) {
	$x = shift(@c);
	$y = shift(@c);
	$poly->addPt(&xlc($x,$y));
    }
    $img->polygon($poly, $c);
}

sub draw_polygon {
    my($img, $e) = @_;
    my(@c, $c, $b);

    @c = split(/ /, $coords[$e]);
    $c = &draw_color($img, $e, $pen_color[$elt]);

    &draw_polygon_1($img, $c, @c);
}

sub draw_ellipsis {
    my($img, $e) = @_;
    my($c);

    $c = &draw_color($img, $e, "black");

    $img->arc(&xlc($cx[$e], $cy[$e]),
	      &scale($radius_x[$e]*2,
		     $radius_y[$e]*2),
	      0, 360, $c);
}

#
# Calculate enclosing polygons/rectangles
#

sub enclose_line {
    my($x1, $y1, $x2, $y2) = @_;
    my(@ec, $x, $y);
    my($dx, $dy);
    
    $dx = $x2-$x1;
    $dy = $y2-$y1;

    ($x, $y) = &line_seg_rel($touch_len, $x1, $y1, -$dy, $dx);
    push(@ec, $x, $y);
    $x = $x + $dx;
    $y = $y + $dy;
    push(@ec, $x, $y);
    ($x, $y) = &line_seg_rel($touch_len * 2, $x, $y, $dy, -$dx);
    push(@ec, $x, $y);
    $x = $x - $dx;
    $y = $y - $dy;
    push(@ec, $x, $y);

    return @ec;
}

sub splice_rect_poly {
    my($rect, $poly) = @_;
    my($n, @np);

    for ($n = 0; $n < $#{$poly}/2; $n++) {
	push(@np, $poly->[$n]);
    }
    for ($n = 0; $n <= $#{$rect}; $n++) {
	push(@np, $rect->[$n]);
    }
    for ($n = ($#{$poly}+1)/2; $n <= $#{$poly}; $n++) {
	push(@np, $poly->[$n]);
    }
    return @np;
}

sub enclose_polyline {
    my(@c) = @_;
    my(@ep, @er);
    
    @ep = ();

    while($#c > 2) {
	@er = &enclose_line(@c[0..3]);
	@ep = &splice_rect_poly(\@er, \@ep);
	shift(@c); shift(@c);
    }
    return @ep;
}

sub draw_title {
    my($img, $w, $h, $title) = @_;
    my($len, $pw, $x, $y, $c);
    
    $len = length($title);
    $pw = $len * 6;		# small font is apparenty 6pix wide
    $x = ($w / 2) - ($pw / 2);	# center text

    $c = &find_color("black", $img);
    $img->string(gdSmallFont, $x, 0, $title, $c);
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

sub draw_img {
    my($elts, $title) = @_;
    my($e, $img, $w, $h, $bg, $c);

    ($w, $h, $c) = &get_area();
    
    $w += $border*2;		# for border & zoom areas
    $h += $border*2;
    $img = new GD::Image($w, $h);
    # The color allocated first is the background
    $bg = &find_color($c, $img);

    &draw_border($img, $w, $h);

    for ($e = 0; $e < $elts; $e++) {
	if (defined($hide[$e])) { next; }
	if      ($type[$e] eq "rectangle") {
	    &draw_rectangle($img, $e);
	} elsif ($type[$e] eq "polyline") {
	    &draw_polyline($img, $e);
	} elsif ($type[$e] eq "text") {
	    &draw_text($img, $e);
	} elsif ($type[$e] eq "polygon") {
	    &draw_polygon($img, $e);
	} elsif ($type[$e] eq "ellipsis") {
	    &draw_ellipsis($img, $e);
	} else {
	    &err("unknown type for obj $e: \'$type[$e]\'");
	}
    }
    &legends($img);
    &draw_title($img, $w, $h, $title);
    return($img);
}

sub err {
    my($msg) = @_;

    printf(STDERR "%s\n", $msg);
    printf("<h2>%s</h2>\n", $msg);
    print $doc->end_html;
    print "\n";
    exit(1);
}

sub warn {
    my($msg) = @_;

    printf("<h2>%s</h2>\n\n", $msg);
    printf(STDERR "%s\n", $msg);
}

# Read in base data, return number of records read.

sub read_data {
    my($fh) = @_;
    my(@f, $nr, $n);

    $nr = 0;
    while(<$fh>) {
	chop;
	@f = split;
	$n = $f[0];
	if (defined($in_load{$n}) &&
	    $f[1] <= $in_load{$n} &&
	    $f[2] <= $out_load{$n})
	{
	    # Hack to ignore e.g. aal5 interfaces with no data
	    next;
	}
	$in_load{$n} = $f[1];
	$out_load{$n} = $f[2];
	$speed{$n} = $f[3];
	$nr++;
    }
    return $nr;
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

# Functions to deal with coloring of lines

sub load_color {
    my($load) = @_;
    my($ix, $i);
    
    if (defined($limits_specified)) {
	for($i = 0; $i <= $#load_color; $i++) {
	    if ($load < $load_limit[$i]) {
		return($load_color[&max(0,$i-1)]);
	    }
	}
	return $load_color[$#load_color];
    } else {
	$ix = int($load/10);
	if ($ix > 9) { $ix = 9; }
	if ($ix < 0) { $ix = 0; }
	return $load_color[$ix];
    }
}

# As rev_name but don't allow /i notation.

sub clean_rev_name {
    my($name) = @_;
    my($rn);

    $rn = &rev_name($name);
    if ($rn =~ /\/i/) {
	return $name;
    }
    return $rn;
}

sub get_name_brush {
    my($img, $name) = @_;
    my($val, $speed, $c, $w);

    if ($name =~ /(.*)\/i/) {
	$name = $1;
	$val = $in_load{$name};
    } else {
	$val = $out_load{$name};
    }

    if (!defined($val)) {
	return &find_color("black", $img);
    }

    $w = &speed_width($speed{$name});
    $c = &load_color($val);

    return &get_brush($img, $w, $c);
}

sub speed_width {
    my($speed) = @_;
    my($n);

    for ($n = 1; defined($high[$n]); $n++) {
	if ($speed < $high[$n]) {
	    return($n);
	}
    }
    return ($n-1);		# max
}

sub read_ranges {
    my($fh) = @_;
    my(@f, $n);

    for ($n = 1; <$fh>; $n++) {
	chomp;
	@f = split(/\s+/, $_, 2);
	$high[$n] = $f[0];
	$lw_text[$n] = $f[1];
    }
}

sub read_lw_file {
    my($f) = @_;

    open(RNG, $f) || &err("Could not open range file $f: $!");
    &read_ranges(RNG);
    close(RNG);
}

sub lw_file {
    my($map) = @_;
    my($lwf);
    
    $lwf = "%MAPDIR%/" . $map . ".rng";
    if (! -f $lwf) {
	$lwf = "%MAPDIR%/default.rng";
	if (! -f $lwf) {
	    &err("Could neither get line-width file for $map nor defaults");
	}
    }
    return $lwf;
}

sub legends {
    my($img) = @_;
    my($e, $i, $c);

    $c = &find_color("black", $img);

    for ($i = 1; defined($high[$i]); $i++) {
	if (!defined($e = $lw_text_elt[$i])) { next; }
	$img->string(gdSmallFont, &xlc($x[$e], $y[$e]),
		     $lw_text[$i], $c);
    }
}

sub map_file {
    my($map) = @_;

    return "%MAPDIR%/" . $map . ".obj";
}

sub xfig_map_file {
    my($map) = @_;

    return "%MAPDIR%/" . $map . ".fig";
}

sub read_map {
    my($map) = @_;
    my($elts, $file);
    
    # Read map file in tgif format
    $file = &map_file($map);
    open(TG, $file) || &err("Could not open map file for $map: $!");
    $elts = &read_tgif(TG);
    close(TG);
    return $elts;
}

#
# HTML-related functions
#

# Translate, return ints

sub xlci {
    my(@c) = @_;
    my(@nc, $n);

    @c = &xlc(@c);
    for ($n = 0; $n <= $#c; $n++) {
	$nc[$n] = int($c[$n]);
    }
    return @nc;
}

sub other_map_url {
    my($elt, $dsp, $type, $select) = @_;
    my($mr) = $mapref[$elt];

    if (!defined($mr)) { return undef; }
    if ($mr =~ /^https?:\/\//) {
	return sprintf("%s,%s,%s,%s", $mr, $dsp, $type, $select);
    }
    if ($mr =~ /^abs-https?:\/\//) {
	$mr =~ s/^abs-//;
	return $mr;
    }
    return &map_ref($mr, $dsp, $type, $select);
}

sub other_map_alt {
    my($elt, $dsp, $type, $select) = @_;
    my($mr) = $mapref[$elt];

    if (defined($mapalt[$elt])) {
	return $mapalt[$elt];
    } else {
	return sprintf("[%s %s %s map]", $mr, $type, $dsp);
    }
}

sub other_map_coords {
    my($elt) = @_;
    my(@c) = split(/ /, $coords[$elt]);
    my($x, $y, $w, $h);

    if ($type[$elt] eq "rectangle") { # convert to polygon
	$x = $c[0];
	$y = $c[1];
	$w = $c[2] - $x;
	$h = $c[3] - $y;
	return ($x, $y, ($x+$w), $y, ($x+$w), ($y+$h), $x, ($y+$h));
    }
    return @c;
}

sub other_map_ref {
    my($elt, $dsp, $type, $select) = @_;
    my($mc, $url, $alt);

    $url = &other_map_url($elt, $dsp, $type, $select);
    $alt = &other_map_alt($elt, $dsp, $type, $select);

    if (!defined($url)) { return ""; }
    if ($type[$elt] eq "rectangle" ||
	$type[$elt] eq "polygon" ||
	$type[$elt] eq "polyline")
    {
	$mc = "<area shape=\"poly\" coords=\"";
	$mc .= join(',', &xlci(&other_map_coords($elt)));
    } elsif ($type[$elt] = "ellipsis") {
	$mc = "<area shape=\"circle\" coords=\"";
	$mc .= join(',', &xlci($cx[$elt], $cy[$elt]), # center-x, center-y
		    &scale(&min($radius_x[$elt], $radius_y[$elt])));
    } else {
	return "";
    }
    $mc .= sprintf("\"\n\thref=\"%s\"", $url);
    if (defined($alt)) {
	$mc .= sprintf("\n\talt=\"%s\"", $alt);
    }
    $mc .= " />\n";
    return $mc;
}

sub imgmap {
    my($elts, $dsp, $type, $select) = @_;
    my($map) = "";
    my($e, $mc, @c, @ec, @fh, @lh, $url, $alt);

    # Emit in reverse order to match with front/back layering...
    for ($e = $elts - 1; $e >= 0; $e--) {
	$mc = "";
	@c = split(/ /, $coords[$e]);

	if (defined($name[$e]) && $name[$e] ne "area") {
	    $url = &get_url($name[$e], $select);
	    $alt = &get_alt($name[$e]);
	    $mc = sprintf("<area shape=\"poly\" coords=\"");

	    if (defined($nosplit[$e])) {
		@ec = &enclose_polyline(@c);
		$mc .= join(',', &xlci(@ec));
		$mc .= sprintf("\"\n\thref=\"%s\"\n\talt=\"%s\" />\n",
			       $url, $alt);
	    } else {
		@fh = &first_half_polyline(@c);
		@ec = &enclose_polyline(@fh);
		$mc .= join(',', &xlci(@ec));
		$mc .= sprintf("\"\n\thref=\"%s\"\n\talt=\"%s\" />\n",
			       $url, $alt);

		$url = &get_url(&clean_rev_name($name[$e]), $select);
		$alt = &get_alt(&clean_rev_name($name[$e]));

		@lh = &last_half_polyline(@c);
		@ec = &enclose_polyline(@lh);
		$mc .= sprintf("<area shape=\"poly\" coords=\"");
		$mc .= join(',', &xlci(@ec));
		$mc .= sprintf("\"\n\thref=\"%s\"\n\talt=\"%s\" />\n",
			       $url, $alt);
	    }
	    $map .= $mc;
	}
	if (defined($mapref[$e])) {
	    $mc = &other_map_ref($e, $dsp, $type, $select);
	    $map .= $mc;
	}
    }
    return $map;
}

sub get_url {
    my($urlc, $select) = @_;
    my($ts) = "hr";

    if ($select eq "peak") {
	$ts = "raw";
    }
    return sprintf("%splot-all/%s,%s,%s,%s",
		   $pfx, $urlc, $datespec, $ts, $graph_type);
}

sub get_alt {
    my($urlc) = @_;

    return sprintf("[%s %s plot]", $urlc, $graph_type);
}

sub getargs {
    my($exp, $map, $dsp, $type, $select);
    my($query);

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
    } elsif (&is_today($dsp)) {
	$exp = 5*60;		# when inspecting current load
    } else {
	$exp = 30*24*60*60;	# one month, really "eternally"
    }

    return($exp, $map, $dsp, $type, $select);
}

sub start_doc {
    my($exp, $map, $dsp, @args) = @_;
    my($title);
    
    # Emit a sensible Expires: header
    if (&is_today($dsp)) {
	print $doc->header(-type => "text/html",
			   -expires => sprintf("+%ds", $exp-30),
			   -refresh => $exp);
	
    } else {
	print $doc->header(-type => "text/html",
			   -expires => sprintf("+%ds", $exp));
    }

    $title = &get_title($map, $dsp, @args);
    print $doc->start_html(-title=>$title);
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

sub map_alt {
    my($map, $dsp, $type, $select) = @_;

    return
	sprintf("[%s %s/%s map for %s]",
		$map, $type, $select, $dsp);

}

sub map_ref {
    my($map, $dsp, $type, $select) = @_;

    return
	sprintf("%s/%s,%s,%s,%s", $ourname,
		$map, $dsp, $type, $select);
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
	$nx_ex = ($nx_base_tm < (time));
	
	if ($pr_ex) {
	    printf("<area shape=\"rect\" coords=\"%s\"\n", &pr_coords($w, $h));
	    printf("\thref=\"%s\"\n", &map_ref($map, $pr_dsp, $type, $select));
	    printf("\talt=\"%s\" />\n"
		   , &map_alt($map, $pr_dsp, $type, $select));
	}
	if ($nx_ex) {
	    printf("<area shape=\"rect\" coords=\"%s\"\n", &nx_coords($w, $h));
	    printf("\thref=\"%s\"\n", &map_ref($map, $nx_dsp, $type, $select));
	    printf("\talt=\"%s\" />\n",
		   &map_alt($map, $pr_dsp, $type, $select));
	}
    }
}

sub add_help_ptr {

    printf("<p>A short <a href=\"%s\">explanation</a>",
	   sprintf("%s../stats/map-doc.html", $pfx));
    printf(" of the map is available\n");
    printf("</p>\n");
}

sub img_names {
    my($m, $dsp, $t, $s) = @_;
    my($b);

    $b = sprintf("lm-tg.%s.%s.%s.%s.png", $m, $dsp, $t, $s);
    my($rn) = sprintf("%HTMLPFX%/imgs/%s", $b);

    if (&is_today($dsp)) {
	return(
	       # Hardcoding refresh period for now to 15 minutes
	       sprintf("%CGIPFX%/ex-png/%s,%s", (15*60)-30, $rn),
	       sprintf("%s/imgs/%s", "%HTMLDIR%", $b)
	       );
    } else {
	return(
	       sprintf("%HTMLPFX%/imgs/%s", $b),
	       sprintf("%s/imgs/%s", "%HTMLDIR%", $b)
	       );
    }
}

sub get_title {
    my($m, $dsp, $t, $s) = @_;

    return sprintf("Map %s for %s showing %s %s",
		   $m, &pretty_datespec($dsp), $s, $t);
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

sub modtime {
    my($f) = @_;

    return (stat($f))[9];
}

sub last_update {

    return strftime("%Y %h %e %H:%M", localtime(&modtime($load_now)));
}


sub produce_map {
    my($exp, $map, $dsp, $type, $select) = @_;
    my($elts, $refname, $file, $img, $title);

    &save_url_comps($dsp, $type);
    &get_data($dsp, $type, $select);
    $elts = &read_map($map);
    &read_lw_file(&lw_file($map));

    $title = &get_title($map, $dsp, $type, $select);

    # Produce image file (PNG)
    ($refname, $file) = &img_names($map, $dsp, $type, $select);

    $img = &draw_img($elts, $title);
    open(OUT, ">$file") ||
	&err("Could not open PNG file $file for $refname for write: $!");
    print OUT $img->png;
    close(OUT);

    # Now produce normal document
    printf("<h2>%s</h2>\n", $title);

    printf("<a href=\"%s\">\n\t<img src=\"%s\" ", $refname, $refname);
    printf("\n\talt=\"[PNG image]\"\n\tusemap=\"#mymap\" />\n</a>\n");

    printf("<map id=\"mymap\" name=\"mymap\">\n");
    printf("%s", &imgmap($elts, $dsp, $type, $select));
    &add_zoom_areas($map, $dsp, $type, $select);
    printf("</map>\n");
    if (&is_today($dsp)) {
	printf("<p>Base data last updated %s\n</p>", &last_update());
    }
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

# Before we emit any HTML, check to see if the requested map file
# exists as a tgif file, and if it doesn't, check if the corresponding
# xfig file exists, and exec the old script instead if it does:

if (! -f &map_file($args[0]) &&
    -f &xfig_map_file($args[0])) {
    exec("%CGIDIR%/xf-load-map", @args);
    printf("Oops, exec failed\n"); # yes, leaves a turd in the HTTP error log
}

&start_doc($exp, @args);	# so that we can emit HTML,
				# be it error messages
				# or the real document
# Validate arguments
if (defined($ai = &invalid_arg("[-A-Za-z0-9_.]*", @args))) {
    &err(sprintf("Invalid argument: %s", $args[$ai]));
}

&produce_map($exp, @args);
