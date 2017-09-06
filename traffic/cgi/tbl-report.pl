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
# Produce tabular summaries covering a given datespec.
# Input is from the tbl-report.html form.
#

push(@INC, "%LIBDIR%");

use CGI qw(:cgi-lib :standard);

require 'date.pl';
require 'search.pl';
require 'tmpfiles.pl';
# require 'filter-lines.pl';


sub make_url {
    my($sorttype, $sortby, $datespec) = @_;
    my($url, $args);
    our(%in);

    $url = $doc->url();
    $args = "?";

    $args .= "datespec" . "=" . $datespec . "&amp;";

    foreach $field ("dsp-type", "type", "t-sort",
		    "tk-sort", "e-sort", "ee-sort", "filter")
    {
	if ($field ne $sorttype) {
	    $args .= $field . "=" . $in{$field} . "&amp;";
	} else {
	    $args .= $field . "=" . $sortby . "&amp;";
	}
    }
    $args .= "submit=Submit";

    return $url . $args;
}

sub make_ref {
    my($fmt, $colhdr, $sorttype, $sortby) = @_;
    our(%in);

    return sprintf("<a href=\"%s\">" . $fmt . "</a>",
		   &make_url($sorttype, $sortby,$in{"datespec"}),
		   $colhdr);
}


sub day_traffic_header {

    printf("%-25s %15s  %15s\n", "", "Busy hour", "Peak sample");
    printf("%-25s %7s %7s  %7s %7s  %7s  %9s\n",
	   &make_ref("%-25s", "Interface", "t-sort", "Name"),
	   &make_ref("%7s", "input",  "t-sort", "Busy+hour+in"),
	   &make_ref("%7s", "output", "t-sort", "Busy+hour+out"),
	   &make_ref("%7s", "input",  "t-sort", "Peak+sample+in"),
	   &make_ref("%7s", "output", "t-sort", "Peak+sample+out"),
	   "average", "speed");
    printf("%-25s %3s  %2s %3s  %2s  %3s  %2s %3s  %2s  %3s %3s  %9s\n", "",
	   "%", "hr", "%", "hr", "%", "hr", "%", "hr",
	   &make_ref("%3s", "%in", "t-sort", "Average+in"),
	   &make_ref("%3s", "out", "t-sort", "Average+out"),
	   "kbit/s");
}

sub day_traffic_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %3s  %2d %3s  %2d  %3s  %2d %3s  %2d  %3s %3s  %9d\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic\">%3d</a>",
		   $l[0], $dsp, $l[1]),
	   $l[2],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic\">%3d</a>",
		   $l[0], $dsp, $l[3]),
	   $l[4],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic\">%3d</a>",
		   $l[0], $dsp, $l[5]),
	   $l[6],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic\">%3d</a>",
		   $l[0], $dsp, $l[7]),
	   $l[8],
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic\">%3d</a>",
		   $l[0], $dsp, $l[9]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic\">%3d</a>",
		   $l[0], $dsp, $l[10]),
	   $l[11]);

}

sub week_traffic_header {

    printf("%-25s %7s  %7s  %15s  %7s\n", "",
	   "Peak", "Busy ", "Busy day  ", "Week");
    printf("%-25s %7s  %7s  %7s %7s  %7s  %9s\n", "",
	   "sample", "hour ", "input", "output", "average", "speed");
    printf("%-25s %3s %3s  %3s %3s  %3s %3s %3s %3s  %3s %3s  %9s\n",
	   &make_ref("%-25s", "Port", "t-sort", "Name"),
	   &make_ref("%3s", "%in", "t-sort", "Peak+sample+in"),
	   &make_ref("%3s", "out", "t-sort", "Peak+sample+out"),
	   &make_ref("%3s", "%in", "t-sort", "Busy+hour+in"),
	   &make_ref("%3s", "out", "t-sort", "Busy+hour+out"),
	   &make_ref("%3s", "%in", "t-sort", "Busy+day+in"), "day",
	   &make_ref("%3s", "out", "t-sort", "Busy+day+out"), "day",
	   &make_ref("%3s", "%in", "t-sort", "Average+in"),
	   &make_ref("%3s", "out", "t-sort", "Average+out"),
	   "kbit/s");
}

sub week_traffic_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %3s %3s  %3s %3s  %3s %3s %3s %3s  %3s %3s  %9s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic\">%3d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic\">%3d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic\">%3d</a>",
		   $l[0], $dsp, $l[3]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic\">%3d</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[5]),
	   $l[6],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[7]),
	   $l[8],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[9]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[10]),
	   $l[11]);
}


sub month_traffic_header {

    printf("%-25s %7s  %16s  %7s\n", "",
	   "Peak", "Busy day   ", "Month");
    printf("%-25s %7s  %7s  %7s  %7s  %9s\n", "",
	   "sample", "input", "output", "average", "Speeds");
    printf("%-25s %3s %3s  %3s %3s  %3s %3s  %3s %3s  %9s\n",
	   &make_ref("%-25s", "Port", "t-sort", "Name"),
	   &make_ref("%3s", "%in", "t-sort", "Peak+sample+in"),
	   &make_ref("%3s", "out", "t-sort", "Peak+sample+out"),
	   &make_ref("%3s", "%in", "t-sort", "Busy+day+in"), "day",
	   &make_ref("%3s", "out", "t-sort", "Busy+day+out"), "day",
	   &make_ref("%3s", "%in", "t-sort", "Average+in"),
	   &make_ref("%3s", "out", "t-sort", "Average+out"),
	   "kbit/s");
}

sub month_traffic_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %3s %3s  %3s %3s  %3s %3s  %3s %3s  %9s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[3]),
	   $l[4],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[5]),
	   $l[6],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic\">%3d</a>",
		   $l[0], $dsp, $l[8]),
	   $l[9]);
}

sub day_traffic_kbit_header {

    printf("%-25s %17s  %17s  %17s  %15s  %15s  %9s\n",
	   "", "Busy hour", "Peak sample", "24hr average",
	   "IPv6 traffic", "IPv6 percent",
	   "speed");
    printf("%s %s %s  %s %s  %s %s  %s %s  %s %s  %9s\n",
	   &make_ref("%-25s", "Interface", "tk-sort", "Name"),
	   &make_ref(  "%8s", "input",     "tk-sort", "Busy+hour+in"),
	   &make_ref(  "%8s", "output",    "tk-sort", "Busy+hour+out"),
	   &make_ref(  "%8s", "input",     "tk-sort", "Peak+sample+in"),
	   &make_ref(  "%8s", "output",    "tk-sort", "Peak+sample+out"),
	   &make_ref(  "%8s", "input",     "tk-sort", "Average+in"),
	   &make_ref(  "%8s", "output",    "tk-sort", "Average+out"),
	   &make_ref(  "%7s", "input",	   "tk-sort", "IPv6+input"),
	   &make_ref(  "%7s", "output",    "tk-sort", "IPv6+output"),
	   &make_ref(  "%7s", "input",     "tk-sort", "IPv6+input+percent"),
	   &make_ref(  "%7s", "output",    "tk-sort", "IPv6+output+percent"),
	   "kbit/s");
}

sub day_traffic_kbit_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %8s %8s  %8s %8s  %8s %8s",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[3]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[5]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[6]),
	);
    if ($l[11] ne "") {
	if ($l[11] ne "n/a") {
	    printf("  %s %s  %s %s",
		   sprintf("<a href=\"plot-all/%s,%s,raw,ip6perc\">%7d</a>",
			   $l[0], $dsp, $l[13]),
		   sprintf("<a href=\"plot-all/%s,%s,raw,ip6perc\">%7d</a>",
			   $l[0], $dsp, $l[14]),
		   sprintf("<a href=\"plot-all/%s,%s,raw,ip6perc\">%7s</a>",
			   $l[0], $dsp, $l[11]),
		   sprintf("<a href=\"plot-all/%s,%s,raw,ip6perc\">%7s</a>",
			   $l[0], $dsp, $l[12])
		);
	} else {
	    printf("  %7s %7s  %7s %7s", $l[13], $l[14], $l[11], $l[12]);
	}
    } else {
	printf("  %7s %7s  %7s %7s", "", "", "", "");
    }
    printf("  %9s\n", $l[7]);
}

sub week_traffic_kbit_header {

    printf("%-25s %17s  %17s  %17s  %17s  %9s\n",
	   &make_ref("%-25s", "Port", "tk-sort", "Name"),
	   "Peak sample", "Busy hour", "Busy day(24h)",
	   "Week average", "speed"); 
    printf("%-25s %8s %8s  %8s %8s  %8s %8s  %8s %8s  %9s\n", "",
	   &make_ref("%8s", "input",  "tk-sort", "Peak+sample+in"),
	   &make_ref("%8s", "output", "tk-sort", "Peak+sample+out"),
	   &make_ref("%8s", "input",  "tk-sort", "Busy+hour+in"),
	   &make_ref("%8s", "output", "tk-sort", "Busy+hour+out"),
	   &make_ref("%8s", "input",  "tk-sort", "Busy+day+in"),
	   &make_ref("%8s", "output", "tk-sort", "Busy+day+out"),
	   &make_ref("%8s", "input",  "tk-sort", "Average+in"),
	   &make_ref("%8s", "output", "tk-sort", "Average+out"),
	   "kbit/s");
}

sub week_traffic_kbit_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %8s %8s  %8s %8s  %8s %8s  %8s %8s  %9s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[3]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[5]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[6]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[8]),
	   $l[9]);
}

sub month_traffic_kbit_header {

    printf("%-25s %17s  %25s  %17s  %s\n",
	   &make_ref("%-25s", "Port", "tk-sort", "Name"),
	   "Peak sample", "-------Busy day------", "Month average",
	   "speed(s)");
    printf("%-25s %8s %8s  %8s %3s %8s %3s  %8s %8s  %9s\n", "",
	   &make_ref("%8s", "input",  "tk-sort", "Peak+sample+in"),
	   &make_ref("%8s", "output", "tk-sort", "Peak+sample+out"),
	   &make_ref("%8s", "input",  "tk-sort", "Busy+day+in"),
	   "day",
	   &make_ref("%8s", "output", "tk-sort", "Busy+day+out"),
	   "day",
	   &make_ref("%8s", "input",  "tk-sort", "Average+in"),
	   &make_ref("%8s", "output", "tk-sort", "Average+out"),
	   "kbit/s");
}

sub month_traffic_kbit_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %8s %8s  %8s %3s %8s %3s  %8s %8s  %9s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[3]),
	   $l[4],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[5]),
	   $l[6],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%8d</a>",
		   $l[0], $dsp, $l[8]),
	   $l[9]);
}

sub day_errs_header {
    my($nf) = @_;

    if ($nf == 15) {
	my $r1 = &make_ref("%-25s", "Interface",    "e-sort", "Name");
	my $r2 = &make_ref("%22s", "inerr hrs >x%", "e-sort", "Error+hours");
	printf("%-25s%22s    %24s %11s\n", $r1, $r2,
	       "----------------- in % ----------------",
	       "-- out ----");
	printf("%-25s  %3s %3s %3s %4s %4s   %7s %7s %7s %7s %7s %5s %5s\n",
	       "",
	       "1.0", "0.1", ".01", "1e-3", "1e-4",
	       &make_ref("%7s", "Errs", "e-sort", "Input+errors"),
	       &make_ref("%7s", "CRC" , "e-sort", "CRC+errors"),
	       &make_ref("%7s", "Frm" , "e-sort", "Framing+errors"),
	       &make_ref("%7s", "Abrt", "e-sort", "Abort+errors"),
	       &make_ref("%7s", "Ign" , "e-sort", "Ignored+packets"),
	       &make_ref("%5s", "Reset","e-sort", "Interface+resets"),
	       &make_ref("%5s", "Disc%","e-sort", "Peak+out+discards")
	    );
    } else {
	printf("%-25s%13s %24s  %11s\n",
	       &make_ref("%-25s", "Interface",    "e-sort", "Name"),
	       &make_ref("%13s", "inerr hrs >x%", "e-sort", "Error+hours"),
	       "------------ in % -----------",
	       "-- out ----");
	printf("%-25s  %3s %3s %3s %5s %5s %5s %5s %5s  %5s %5s\n", "",
	       "1.0", "0.1", ".01",
	       &make_ref("%5s", "Errs", "e-sort", "Input+errors"),
	       &make_ref("%5s", "CRC" , "e-sort", "CRC+errors"),
	       &make_ref("%5s", "Frm" , "e-sort", "Framing+errors"),
	       &make_ref("%5s", "Abrt", "e-sort", "Abort+errors"),
	       &make_ref("%5s", "Ign" , "e-sort", "Ignored+packets"),
	       &make_ref("%5s", "Reset","e-sort", "Interface+resets"),
	       &make_ref("%5s", "Disc%","e-sort", "Peak+out+discards")
	    );
    }
}

sub day_errs_line {
    my($dsp, @l) = @_;

    if ($#l == 14) {
	printf("%-25.25s  %3s %3s %3s %4s %4s   %7s %7s %7s %7s %7s %5s %5s\n",
	       $l[0], $l[1], $l[2], $l[3], $l[13], $l[14],
	       sprintf("<a href=\"plot-all/%s,%s,raw,errors\">%7s</a>",
		       $l[0], $dsp, $l[4]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,errors\">%7s</a>",
		       $l[0], $dsp, $l[5]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,errors\">%7s</a>",
		       $l[0], $dsp, $l[6]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,errros\">%7s</a>",
		       $l[0], $dsp, $l[7]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,discards\">%5s</a>",
		       $l[0], $dsp, $l[8]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,resets\">%5s</a>",
		       $l[0], $dsp, $l[9]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,discards\">%5s</a>",
		       $l[0], $dsp, $l[10]),
	       $l[12]);
    } else {
	printf("%-25.25s  %3s %3s %3s %5s %5s %5s %5s %5s  %5s %5s\n",
	       $l[0], $l[1], $l[2], $l[3],
	       sprintf("<a href=\"plot-all/%s,%s,raw,errors\">%5s</a>",
		       $l[0], $dsp, $l[4]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,errors\">%5s</a>",
		       $l[0], $dsp, $l[5]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,errors\">%5s</a>",
		       $l[0], $dsp, $l[6]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,errros\">%5s</a>",
		       $l[0], $dsp, $l[7]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,discards\">%5s</a>",
		       $l[0], $dsp, $l[8]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,resets\">%5s</a>",
		       $l[0], $dsp, $l[9]),
	       sprintf("<a href=\"plot-all/%s,%s,raw,discards\">%5s</a>",
		       $l[0], $dsp, $l[10]),
	       $l[12]);
    }
}

sub week_errs_header {

    printf("%-25s %11s %9s  %9s  %11s  %14s\n",
	   &make_ref("%-25s", "Port", "e-sort", "Name"),
	   &make_ref("%11s", "hrs>=%InErr", "e-sort", "Error+hours"),
	   &make_ref("%9s", "In-errs ", "e-sort", "Input+errors"),
	   &make_ref("%9s", "Ignores ", "e-sort", "Ignored+packets"),
	   &make_ref("%11s", "Resets  ","e-sort", "Interface+resets"),
	   &make_ref("%14s", "Out discard %", "e-sort", "Output+discards"),
	   );
    printf("%-25s %3s %3s %3s  %4s %4s  %4s %4s  %5s %5s  %4s %4s %4s\n", "",
	   "1.0", "0.1", ".01", "PDay", "Avg", "PDay", "Avg",
	   "PkDay", "total",
	   &make_ref("%4s", "PkHr", "e-sort", "Peak+out+discards"),
	   &make_ref("%4s", "PDay", "e-sort", "Peak+out+discards"),
	   &make_ref("%4s", "Avg",  "e-sort", "Output+discards"),
	   );
}

sub week_errs_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %3s %3s %3s  %4s %4s  %4s %4s  %5s %5s  %4s %4s %4s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,day,error-hrs\">%3s</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,day,error-hrs\">%3s</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,day,error-hrs\">%3s</a>",
		   $l[0], $dsp, $l[3]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,errors\">%4s</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,errors\">%4s</a>",
		   $l[0], $dsp, $l[5]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,discards\">%4s</a>",
		   $l[0], $dsp, $l[6]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,discards\">%4s</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,resets\">%5s</a>",
		   $l[0], $dsp, $l[8]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,resets\">%5s</a>",
		   $l[0], $dsp, $l[9]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,discards\">%4s</a>",
		   $l[0], $dsp, $l[10]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,discards\">%4s</a>",
		   $l[0], $dsp, $l[11]),
	   sprintf("<a href=\"plot-all/%s,%s,day,discards\">%4s</a>",
		   $l[0], $dsp, $l[12])
	   );
}

sub day_eerrs_header {

    printf("%-25s  %35s  %17s\n",
	   &make_ref("%-25s", "Interface", "ee-sort", "Name"),
	   "--------------  in % --------------",
	   "----- out % -----");
    printf("%-25s  %5s %5s %5s %5s %5s %5s  %5s %5s %5s\n", "",
	   &make_ref("%5s", "Errs", "ee-sort", "Input+errors"),
	   &make_ref("%5s", "CRC",  "ee-sort", "CRC+errors"),
	   &make_ref("%5s", "Frame","ee-sort", "Framing+errors"),
	   &make_ref("%5s", "Runts","ee-sort", "Runts"),
	   &make_ref("%5s", "Giant","ee-sort", "Giants"),
	   &make_ref("%5s", "Ignor","ee-sort", "Ignored+packets"),
	   &make_ref("%5s", "Errs", "ee-sort", "Output+errors"),
	   &make_ref("%5s", "Disc", "ee-sort", "Output+discards"),
	   &make_ref("%5s", "Colls", "ee-sort", "Collisions"),
	   );
}

sub day_eerrs_line {
    my($dsp, @l) = @_;

    printf("%-25.25s  %5s %5s %5s %5s %5s %5s  %5s %5s %5s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,hr,errors\">%5s</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,eerrs\">%5s</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,eerrs\">%5s</a>",
		   $l[0], $dsp, $l[3]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,eerrs\">%5s</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,eerrs\">%5s</a>",
		   $l[0], $dsp, $l[5]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,discards\">%5s</a>",
		   $l[0], $dsp, $l[6]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,errors\">%5s</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,discards\">%5s</a>",
		   $l[0], $dsp, $l[8]),
#	   sprintf("<a href=\"plot-all/%s,%s,hr,eerrs\">%5s</a>",
#		   $l[0], $dsp, $l[9])
	   $l[9]
	   );
}

%put_header = (
	       "traffic" => {
		   "day" => \&day_traffic_header,
		   "week" => \&week_traffic_header,
		   "month" => \&month_traffic_header,
	       },
	       "traffic-kbit" => {
		   "day" => \&day_traffic_kbit_header,
		   "week" => \&week_traffic_kbit_header,
		   "month" => \&month_traffic_kbit_header,
	       },
	       "errors" => {
		   "day" => \&day_errs_header,
		   "week" => \&week_errs_header,
	       },
	       "ether-errs" => {
		   "day" => \&day_eerrs_header,
	       },
	       );


%put_line = (
	     "traffic" => {
		 "day" => \&day_traffic_line,
		 "week" => \&week_traffic_line,
		 "month" => \&month_traffic_line,
	     },
	     "traffic-kbit" => {
		 "day" => \&day_traffic_kbit_line,
		 "week" => \&week_traffic_kbit_line,
		 "month" => \&month_traffic_kbit_line,
	     },
	     "errors" => {
		 "day" => \&day_errs_line,
		 "week" => \&week_errs_line,
	     },
	     "ether-errs" => {
		 "day" => \&day_eerrs_line,
	     },
	     );


%sortargs = (
	     "traffic" => {
		 "day" => {
		     "Average in"	=> "-n -r +9 +10 +1 +3 +5 +7",
		     "Average out"	=> "-n -r +10 +9 +3 +1 +7 +5",
		     "Busy hour in"	=> "-n -r +1 +3 +5 +7 +9 +10",
		     "Busy hour out"	=> "-n -r +3 +1 +7 +5 +10 +9",
		     "Peak sample in"	=> "-n -r +5 +7 +1 +3 +10 +9",
		     "Peak sample out"	=> "-n -r +7 +5 +3 +1 +9 +10",
		     "Name"		=> "",
		 },
		 "week" => {
		     "Average in"	=> "-n -r +9 +10 +1 +2 +3 +4",
		     "Average out"	=> "-n -r +10 +9 +2 +1 +4 +3",
		     "Busy day in"	=> "-n -r +5 +7 +9 +10 +1 +2",
		     "Busy day out"	=> "-n -r +7 +5 +10 +9 +2 +1",
		     "Busy hour in"	=> "-n -r +3 +4 +1 +2 +9 +10",
		     "Busy hour out"	=> "-n -r +4 +3 +2 +1 +10 +9",
		     "Peak sample in"	=> "-n -r +1 +2 +3 +4 +9 +10",
		     "Peak sample out"	=> "-n -r +2 +1 +4 +3 +10 +9",
		     "Name"		=> "",
		 },
		 "month" => {
		     "Average in"	=> "-n -r +7 +8 +3 +5 +1 +2",
		     "Average out"	=> "-n -r +8 +7 +5 +3 +2 +1",
		     "Busy day in"	=> "-n -r +3 +5 +7 +8 +1 +2",
		     "Busy day out"	=> "-n -r +5 +3 +8 +7 +2 +1",
		     "Busy hour in"	=> "-n -r +3 +5 +7 +8 +1 +2",
		     "Busy hour out"	=> "-n -r +5 +3 +8 +7 +2 +1",
		     "Peak sample in"	=> "-n -r +1 +2 +3 +5 +7 +8",
		     "Peak sample out"	=> "-n -r +2 +1 +5 +3 +8 +7",
		     "Name"		=> "",
		 },
	     },
	     "traffic-kbit" => {
		 "day" => {
		     "Average in"	=> "-n -r +5 +6 +3 +4 +1 +2",
		     "Average out"	=> "-n -r +6 +5 +4 +3 +2 +1",
		     "Busy hour in"	=> "-n -r +1 +2 +3 +4 +5 +6",
		     "Busy hour out"	=> "-n -r +2 +1 +4 +3 +6 +5",
		     "Peak sample in"	=> "-n -r +3 +4 +1 +2 +5 +6",
		     "Peak sample out"	=> "-n -r +4 +3 +2 +1 +6 +5",
		     "Name"		=> "",
		     "IPv6 input"       => "-n -r +13 +14 +0",
		     "IPv6 output"      => "-n -r +14 +13 +0",
		     "IPv6 input percent" => "-n -r +11 +12 +0",
		     "IPv6 output percent" => "-n -r +12 +11 +0",
		 },
		 "week" => {
		     "Average in"	=> "-n -r +7 +8 +5 +6 +3 +4 +1 +2",
		     "Average out"	=> "-n -r +8 +7 +6 +5 +4 +3 +2 +1",
		     "Busy day in"	=> "-n -r +5 +6 +1 +2 +3 +4 +7 +8",
		     "Busy day out"	=> "-n -r +6 +5 +2 +1 +4 +3 +8 +7",
		     "Busy hour in"	=> "-n -r +3 +4 +1 +2 +5 +6 +7 +8",
		     "Busy hour out"	=> "-n -r +4 +3 +2 +1 +6 +5 +8 +7",
		     "Peak sample in"	=> "-n -r +1 +2 +3 +4 +5 +6 +7 +8",
		     "Peak sample out"	=> "-n -r +2 +1 +4 +3 +6 +5 +8 +7",
		     "Name"		=> "",
		 },
		 "month" => {
		     "Average in"	=> "-n -r +7 +8 +3 +5 +1 +2",
		     "Average out"	=> "-n -r +8 +7 +5 +3 +2 +1",
		     "Busy day in"	=> "-n -r +3 +5 +7 +8 +1 +2",
		     "Busy day out"	=> "-n -r +5 +3 +8 +7 +2 +1",
		     "Peak sample in"	=> "-n -r +1 +2 +3 +5 +7 +8",
		     "Peak sample out"	=> "-n -r +2 +1 +5 +3 +8 +7",
		     "Name"		=> "",
		 },
	     },
	     "errors" => {
		 "day" => {
		     "Error hours"	=> "-n -r +1 +2 +3 +4",
		     "Input errors"	=> "-n -r +4 +5 +6 +7 +8",
		     "CRC errors"	=> "-n -r +5 +4 +6 +7 +8",
		     "Framing errors"	=> "-n -r +6 +4 +5 +7 +8",
		     "Abort errors"	=> "-n -r +7 +4 +5 +6 +8",
		     "Ignored packets"	=> "-n -r +8 +4 +5 +6 +7",
		     "Interface resets" => "-n -r +9 +4 +5 +6 +7 +8",
		     "Output discards"	=> "-n -r +10 +9 +4",
		     "Peak out discards"=> "-n -r +10 +9 +4",
		     "Name"		=> "",
		 },
		 "week" => {
		     "Error hours"	=> "-n -r +1 +2 +3 +4",
		     "Input errors"	=> "-n -r +4 +5 +1 +2 +3",
		     "CRC errors"	=> "-n -r +4 +5 +1 +2 +3",
		     "Framing errors"	=> "-n -r +4 +5 +1 +2 +3",
		     "Abort errors"	=> "-n -r +4 +5 +1 +2 +3",
		     "Ignored packets"	=> "-n -r +6 +7 +1 +2 +3",
		     "Interface resets" => "-n -r +8 +9 +1 +2 +3",
		     "Output discards"	=> "-n -r +12 +11 +10",
		     "Peak out discards"=> "-n -r +10 +11 +12",
		     "Name"		=> "",
		 },
	     },
	     "ether-errs" => {
		 "day" => {
		     "Input errors"	=> "-n -r +1 +2 +3",
		     "CRC errors"	=> "-n -r +2 +1 +3",
		     "Framing errors"	=> "-n -r +3 +1 +2",
		     "Runts"		=> "-n -r +4 +1 +2",
		     "Giants"		=> "-n -r +5 +1 +2",
		     "Ignored packets"	=> "-n -r +6 +1 +2",
		     "Output errors"	=> "-n -r +7 +1 +2",
		     "Output discards"	=> "-n -r +8 +1 +2",
		     "Collisions"	=> "-n -r +9 +1 +2",
		     "Name"		=> "",
		 },
	     },
	     );
	     
%ifcategories = ("3"  => "serial", # HDH 1822
		 "4"  => "serial", # DDN X.25
		 "5"  => "serial", # x.25 (rfc877)
		 "22" => "serial", # proprietary serial
		 "23" => "serial", # PPP
		 "32" => "serial", # Frame relay
		 
		 "6"  => "ethernet", # Ethernet
		 
		 "15" => "fddi", # FDDI
		 
		 "37" => "atm",	# ATM
		 "39" => "atm",	# Really SONET
		 );

%ift_filter_name = (
		    "serial" => "Only serial interfaces",
		    "ethernet" => "Only ethernet interfaces",
		    "fddi" => "Only FDDI interfaces",
		    "atm" => "Only ATM interfaces",
		    "all" => "All interface types",
		    );

%ift_field = (
	      "traffic" => {
		  "day" => 12,
		  "week" => 12,
		  "month" => 10,
	      },
	      "traffic-kbit" => {
		  "day" => 8,
		  "week" => 10,
		  "month" => 10,
	      },
	      "errors" => {
		  "day" => 12,
		  "week" => 13,
	      },
	      "ether-errs" => {
		  "day" => undef, # no field here...
	      },
	      );


%filename = (
	     "traffic" => "traffic",
	     "traffic-kbit" => "traffic.kbit",
	     "errors" => "errors.perc",
	     "ether-errs" => "ether_errs.perc",
	     );


%dsp_t_to_desc = ("day" => "Daily",
		  "week" => "Weekly",
		  "month" => "Monthly",
		  );
		  
%report_type_title = ("traffic" => "traffic",
		      "traffic-kbit" => "traffic (kbit/s)",
		      "errors" => "error",
		      "ether-errs" => "ethernet error"
		      );


sub err {
    my($msg) = @_;

    printf("<h2>$msg</h2>\n");
}


sub report {
    my($dsp, $dsp_t, $type, $sortfield, $dn) = @_;
    my($title, $f, $sortargs, $ift_filter, $reg_filter);
    my($put_header, $filter_ift, $iftf, $filter_r, $put_line);
    my($tmpf, $cmd, $errf, $ret);
    our(%in);

    if (!defined ($put_line = $put_line{$type}{$dsp_t})) {
	&err("Sorry, no support for $type / $dsp_t report");
	return undef;
    }

    if (! defined($sortargs = $sortargs{$type}{$dsp_t}{$sortfield})) {
	&err("Don't know how to sort $type / $dsp_t by $sortfield");
	return undef;
    }

    $f = $dn . "/" . $filename{$type};
    if (! -f $f) {
	&err("There is apparently no data for this date ($f does not exist)");
	return undef;
    }

    $title = sprintf("%s %s summary %s",
		     $dsp_t_to_desc{$dsp_t},
		     $report_type_title{$type},
		     &pretty_datespec($dsp));

    print($doc->start_html(-title => $title));
    print("<h2>$title</h2>\n");
    
    printf("<h2>Sorted by $sortfield");
    if (defined($ift_filter = $in{"filter"})) {
	printf(", %s", $ift_filter_name{$ift_filter});
    }
    if (defined($reg_filter = $in{"f-region"})) {
	if ($reg_filter ne "All interfaces") {
	    if ($reg_filter eq "Only a given region") {
		printf(", Only region %s", $in{"region"});
	    } else {
		printf(", %s", $reg_filter);
	    }
	}
    }
    printf("</h2>\n");

    my $dsp = $in{"datespec"};
    if ($dsp eq "") {
	$dsp = &make_datespec($dsp_t, "");
				# default is to show previous "whatever"
				# data (latest report)
    }

    printf("<table width=\"50%%\">\n");
    printf(" <tr>\n");
    printf("  <td align=\"left\">\n");
    printf("   <a href=\"%s\">Previous</a>\n",
	   &make_url($sortfield{$type},
		     $in{$sortfield{$type}},
		     &previous_datespec($dsp)));
    printf("  </td>\n");
    # Can't show report for today (not produed before after midnight)
    if ($dsp ne &make_datespec($dsp_t, "")) {
	printf("  <td align=\"right\">\n");
	printf("   <a href=\"%s\">Next</a><br />\n",
	   &make_url($sortfield{$type},
		     $in{$sortfield{$type}},
		     &next_datespec($dsp)));
	printf("  </td>\n");
    }
    printf(" </tr>\n");
    printf("</table>\n\n");

    printf("<object>\n");
    printf("<hr />\n");
    printf("<pre>\n");

    # Output heading

    if (! defined($put_header = $put_header{$type}{$dsp_t})) {
	&err("Oops, do not know how put heading for $type / $dsp_t");
	printf("</pre>\n");
	return undef;
    }
    #
    # Prepare to output data.
    #

    # Are we filtering on interface type?
    if (defined $in{"filter"}) {
	if ($in{"filter"} eq "all") {
	    $filter_ift = 0;
	} else {
	    $filter_ift = 1;
	}
    } else {
	$filter_ift = 0;
    }
    if ($filter_ift) {
	$iftf = $ift_field{$type}{$dsp_t};
    }

    # Are we filtering on "region"? (Not fully implemented yet)
    if (defined $in{"filter-r"}) {
	$filter_r = 1;
    }
    
    $tmpf = &new_temp();
    $errf = &new_temp();
    $cmd = sprintf("sort %s %s > %s 2>$errf", $sortargs, $f, $tmpf);
    $ret = system($cmd);
    if ($ret != 0) {
	open(ERR, $errf);
	print while (<ERR>);
	close(ERR);
	&err("Plot failed ret = $ret");
	printf("</pre>\n");
	return undef;
    }

    # Check number of fields in output
    open(IN, $tmpf);
    $_ = <IN>;
    @_ = split;
    my $fields = $#_ + 1;
    close(IN);

    &$put_header($fields);

    printf("\n");

    #
    # Now spit out the data
    #

    open(IN, $tmpf);
    while(<IN>) {
	chop;
	@_ = split;
	if ($filter_ift) {
	    if ($iftf) {
		if ($ifcategories{$_[$iftf]} ne $in{"filter"}) {
#		    printf("Wrong iftype: $_\n");
#		    printf("Filter=%s\n", $in{"filter"});
#		    printf("iftf=%d\n", $iftf);
#		    printf("iftf in line=%s\n", $_[$iftf]);
#		    printf("ifcat=%s\n", $ifcategories{$_[$iftf]});
		    next;
		}
	    }
	}
# Oops, need a "date" here.  Not trivial for all the reports
# since some of them cover more than one day.
#
#	if ($filter_r) {
#	    if (! &include_intf($_[0], $date,
#				$in{"f-region"},
#				$in{"region"}))
#	    {
#		next;
#	    }
#	}
	&$put_line($dsp, @_);
    }
    close(IN);

    printf("</pre>\n");
    printf("<hr />\n");
    printf("</object>\n");
}


%rd_finder = ("day"	=> \&find_day_report_dir,
	      "week"	=> \&find_week_report_dir,
	      "month"	=> \&find_month_report_dir,
	      );

%sortfield = (
	      "traffic"		=> "t-sort",
	      "traffic-kbit"	=> "tk-sort",
	      "errors"		=> "e-sort",
	      "ether-errs"	=> "ee-sort",
	      );

our %valid_sortby;

# Init based on contents of %sortargs hash
foreach my $t (keys %sortargs) {
    foreach my $dt (keys %{ $sortargs{$t} }) {
	foreach my $sa (keys %{ %{ $sortargs{$t} }{$dt}}) {
	    $valid_sortby{$sa} = 1;
	}
    }
}


sub check_and_report {
    my($dsp, $dsp_t);
    my($tm, $nd, $dn, $find, $reporter, $sortby);
    our(%in, %rd_finder, %valid_sortby);

    if (!defined($rd_finder{$in{"dsp-type"}})) {
	&err("Illegal datespec type");
	return undef;
    }

    $dsp = &make_datespec($dsp_t = $in{"dsp-type"}, $in{"datespec"});
    # Pretend that the unambiguated datespec returned was what
    # was originally specified:
    $in{"datespec"} = $dsp;

    ($tm, $nd) = &decode_datespec($dsp);
    if (! defined($tm)) {
	&err("Illegal date format: $dsp");
	return undef;
    }

    $type = $in{"type"};

    if (! defined($find = $rd_finder{$dsp_t})) {
	&err("Sorry, no support for $dsp_t / $type reports");
	return undef;
    }

    if (! defined($dn = &$find($dsp))) {
	&err("No report found for $dsp");
	return undef;
    }

    $sortby = $in{$sortfield{$type}};
    if (!defined($sortby)) {
	&err("Do not know how to sort $type reports");
	return undef;
    }

    if (!defined($valid_sortby{$sortby})) {
	&err("Invalid sort-by value");
	return undef;
    }

    &report($dsp, $dsp_t, $type, $sortby, $dn);
}


#
# Main
#

$doc = new CGI;

print $doc->header(-type => "text/html");

&ReadParse();
&check_and_report();

print $doc->end_html;
print "\n";
&remove_temp_files();
