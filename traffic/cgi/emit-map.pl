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
# Emit a network map given as parameter, stored in html/pics, add a
# client-side image map if db/<map>.coords exists.
#
# This is currently only a proof-of-concept.
#

use CGI qw(:cgi-lib);

push(@INC, "/archive/traffic/lib");

require 'date.pl';
require 'utils.pl';


sub err {
    my($msg) = @_;

    printf("<h2>%s</h2>\n", $msg);
    print $doc->end_html;
    print "\n";
}

sub emit_map {
    my($map, $plot_type) = @_;
    my($mapf, $mapref, $coord_f, $has_coords, $dsp, $imap);
    my($url, $alt, $n, $i);

    $mapf = "%HTMLDIR%/pics/" . $map . ".png";
    if (! -f $mapf) {
	&err("Map $map does not exist");
	return undef;
    }
    $mapref = sprintf("%HTMLPFX%/pics/%s.png", $map);

    printf("<h2>Map %s</h2>\n", $map);

    $coord_f = "%DBDIR%/" . $map . ".coords";
    if (-f $coord_f) {
	if (!open(IN, $coord_f)) {
	    &err("Could not read $coord_f: $!");
	    return undef;
	}
	$has_coords = 1;
	
	printf("The image below is \"clickable\";\n");
	printf("the sensitive areas are marked.\n");
	printf("Clicking on a sensitive area brings up");
	printf(" yesterday's %s plot for the corresponding port.\n",
	       $plot_type);
	       
	printf("<hr>\n");

	$dsp = &yesterday_spec();
	$imap = "<map name=\"mymap\">\n";
	while(<IN>) {
	    chop;
	    @_ = split;
	    $n = $_[$#_];	# extract name
	    $url = sprintf("%splot-all/%s,%s,hr,%s",
			   $pfx, $n, $dsp, $plot_type);
	    $alt = sprintf("%s plot, %s for port %s", $plot_type, $dsp, $n);

	    if ($_[0] eq "R") {
		$imap .= sprintf("<area shape=rect coords=\"%s,%s\"\n\t",
				 $_[1], $_[2]);
		$imap .= sprintf("href=\"%s\"\n\talt=\"%s\">\n",
				 $url, $alt);

	    } elsif ($_[0] eq "P") {
		$imap .= sprintf("<area shape=poly coords=\"");
		foreach $i (1 .. ($#_ - 1)) {
		    $imap .= sprintf("%s,", $_[$i]);
		}
		chop($imap);
		$imap .= sprintf("\"\n\thref=\"%s\"\n\talt=\"%s\">\n",
				 $url, $alt);

	    } else {
		&err("<pre>Unknown coords line:\n$_\n</pre>");
		return undef;
	    }
	}
	printf("%s", $imap);
	printf("</map>\n");
    }

    printf("<img src=\"%s\" ", $mapref);
    printf("alt=\"[PNG map]\"");
    if ($has_coords) {
	printf(" usemap=\"#mymap\"");
    }
    printf(">\n");
    printf("<hr>\n");
}


#
# Main
#

$doc = new CGI;
print $doc->header(-type => "text/html",
		   -expires => sprintf("+%ds",
				       &secs_to_expiry("day")));

print $doc->start_html(-title => "Map page");

# &ReadParse();

$pfx="";
if ($ENV{'QUERY_STRING'}) {
    $query = $ENV{'QUERY_STRING'};
} elsif ($ENV{'PATH_INFO'}) {
    $query = $ENV{'PATH_INFO'};
    $query =~ s/^\///;
    $pfx = "../";
} else {
    $query = "@ARGV";
}

($map, $plot_type) = split(/\s*,\s*/, "$query");

# Do argument validation
@al = ($map, $plot_type);
if (defined($ai = &invalid_arg("[-A-Za-z0-9_.]*", @al))) {
    &err(sprintf("Invalid argument: %s", $al[$ai]));
    exit 1;
}

&emit_map($map, $plot_type);
