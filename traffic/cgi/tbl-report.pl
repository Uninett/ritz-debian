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


sub day_traffic_header {

    printf("%-25s %15s  %15s\n", "", "Busy hour", "Peak sample");
    printf("%-25s %7s %7s  %7s %7s  %7s  %7s\n",
	   "Interface", "input", "output",
	   "input", "output", "average", "speed");
    printf("%-25s %3s  %2s %3s  %2s  %3s  %2s %3s  %2s  %3s %3s  %7s\n", "",
	   "%", "hr", "%", "hr", "%", "hr", "%", "hr",
	   "%in", "out", "kbit/s");
}

sub day_traffic_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %3s  %2d %3s  %2d  %3s  %2d %3s  %2d  %3s %3s  %7d\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic\">%3d</a>",
		   $l[0], $dsp, $l[1]),
	   $l[2],
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic\">%3d</a>",
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
    printf("%-25s %7s  %7s  %7s %7s  %7s  %7s\n", "",
	   "sample", "hour ", "input", "output", "average", "speed");
    printf("%-25s %3s %3s  %3s %3s  %-3s %3s %-3s %3s  %3s %3s  %6s\n", "",
	   "%in", "out", "%in", "out", "%", "day", "%", "day",
	   "%in", "out", "kbit/s");
}

sub week_traffic_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %3s %3s  %3s %3s  %3s %3s %3s %3s  %3s %3s  %7s\n",
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
    printf("%-25s %7s  %7s  %7s  %7s  %7s\n", "Port",
	   "sample", "input", "output", "average", "Speeds");
    printf("%-25s %3s %3s  %3s %3s  %3s %3s  %3s %3s  %6s\n", "",
	   "%in", "out", "%", "day", "%", "day", "%in", "out", "kbit/s");
}

sub month_traffic_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %3s %3s  %3s %3s  %3s %3s  %3s %3s  %7s\n",
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

    printf("%-25s %13s  %13s  %13s  %7s\n",
	   "", "Busy hour", "Peak sample", "24hr average", "speed");
    printf("%-25s %6s %6s  %6s %6s  %6s %6s  %7s\n",
	   "Interface", "input", "output", "input", "output",
	   "input", "output", "kbit/s");
}

sub day_traffic_kbit_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %6s %6s  %6s %6s  %6s %6s  %7s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[3]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[5]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[6]),
	   $l[7]);
}

sub week_traffic_kbit_header {

    printf("%-25s %13s  %13s  %13s  %13s  %7s\n", "Port",
	   "Peak sample", "Busy hour", "Busy day(24h)",
	   "Week average", "speed"); 
    printf("%-25s %6s %6s  %6s %6s  %6s %6s  %6s %6s  %7s\n", "",
	   "input", "output", "input", "output", "input", "output",
	   "input", "output", "kbit/s");
}

sub week_traffic_kbit_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %6s %6s  %6s %6s  %6s %6s  %6s %6s  %7s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[3]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[5]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[6]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[8]),
	   $l[9]);
}

sub month_traffic_kbit_header {

    printf("%-25s %13s  %21s  %13s  %s\n", "Port",
	   "Peak sample", "-------Busy day------", "Month average",
	   "speed(s)");
    printf("%-25s %6s %6s  %6s %3s %6s %3s  %6s %6s  %7s\n", "",
	   "input", "output", "input", "day", "output", "day",
	   "input", "output", "kbit/s");
}

sub month_traffic_kbit_line {
    my($dsp, @l) = @_;

    printf("%-25.25s %6s %6s  %6s %3s %6s %3s  %6s %6s  %7s\n",
	   $l[0],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[1]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[2]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[3]),
	   $l[4],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[5]),
	   $l[6],
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,day,traffic-kbit\">%6d</a>",
		   $l[0], $dsp, $l[8]),
	   $l[9]);
}

sub day_errs_header {

    printf("%-25s%13s %24s  %11s\n", "Interface",
	   "inerr hrs >x%",
	   "--------- in % ---------",
	   "-- out ----");
    printf("%-25s  %3s %3s %3s %4s %4s %4s %4s %4s  %5s %5s\n", "",
	   "1.0", "0.1", ".01", "Errs", "CRC", "Frm", "Abrt", "Ign",
	   "Reset", "Disc%");
}

sub day_errs_line {
    my($dsp, @l) = @_;

    printf("%-25.25s  %3s %3s %3s %4s %4s %4s %4s %4s  %5s %5s\n",
	   $l[0], $l[1], $l[2], $l[3],
	   sprintf("<a href=\"plot-all/%s,%s,hr,errors\">%4s</a>",
		   $l[0], $dsp, $l[4]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,errors\">%4s</a>",
		   $l[0], $dsp, $l[5]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,errors\">%4s</a>",
		   $l[0], $dsp, $l[6]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,errros\">%4s</a>",
		   $l[0], $dsp, $l[7]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,discards\">%4s</a>",
		   $l[0], $dsp, $l[8]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,resets\">%4s</a>",
		   $l[0], $dsp, $l[9]),
	   sprintf("<a href=\"plot-all/%s,%s,hr,discards\">%4s</a>",
		   $l[0], $dsp, $l[10]),
	   sprintf("<a href=\"plot-all/%s,%s,raw,discards\">%4s</a>",
		   $l[0], $dsp, $l[10]),
	   $l[12]);
}

sub week_errs_header {

    printf("%-25s %11s %9s  %9s  %11s  %14s\n", "Port",
	   "hrs>=%InErr", "In-errs ", "Ignores ", "Resets  ",
	   "Out discard %");
    printf("%-25s %3s %3s %3s  %4s %4s  %4s %4s  %5s %5s  %4s %4s %4s\n", "",
	   "1.0", "0.1", ".01", "PDay", "Avg", "PDay", "Avg",
	   "PkDay", "total", "PkHr", "PDay", "Avg");
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

    printf("%-25s  %35s  %17s\n", "Interface",
	   "--------------  in % --------------",
	   "----- out % -----");
    printf("%-25s  %5s %5s %5s %5s %5s %5s  %5s %5s %5s\n", "",
	   "Errs", "CRC", "Frame", "Runts", "Giant", "Ignor",
	   "Errs", "Disc", "Colls");
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
    
    printf("<p><h2>Sorted by $sortfield");
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
    printf("<hr>\n");
    printf("<p>\n");
    printf("<pre>\n");

    # Output heading

    if (! defined($put_header = $put_header{$type}{$dsp_t})) {
	&err("Oops, do not know how put heading for $type / $dsp_t");
	printf("</pre>\n");
	return undef;
    }
    &$put_header();

    printf("\n");

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
    printf("<hr>\n");
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


sub check_and_report {
    my($dsp, $dsp_t);
    my($tm, $nd, $dn, $find, $reporter, $sortfield);

    $dsp = &make_datespec($dsp_t = $in{"dsp-type"}, $in{"datespec"});

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

    $sortfield = $in{$sortfield{$type}};

    if (!defined($sortfield)) {
	&err("Do not know how to sort $type reports");
	return undef;
    }

    &report($dsp, $dsp_t, $type, $sortfield, $dn);
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
