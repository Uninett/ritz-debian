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
# Process form intf-laod.html, redirect if input makes sense.
#

use CGI qw(:cgi-lib);

push(@INC, "%LIBDIR%");

require 'date.pl';

sub err {
    my($msg) = @_;

    print $doc->header(-type => "text/html");
    print $doc->start_html(-title => "Form input error");
    printf("<h2>Form input error</h2>\n");
    printf("%s\n", $msg);
    print $doc->end_html;
    print "\n";
}

sub check_input {
    my($dsp, $tm, $nd, $dsp_t);
    my($intf, $url);
    
    $dsp = &make_datespec($dsp_t = $in{"dsp-type"}, $in{"datespec"});
    ($tm, $nd) = &decode_datespec($dsp);

    if (! defined($tm)) {
	&err("Illegal date format: $dsp");
	return undef;
    }
    
    $intf = $in{"intf"};

    if (length($intf) == 0) {
	&err("Must specify the port name");
	return undef;
    }
    
    $res = $in{"res"};

    if (($dsp_t eq "month" || $dsp_t eq "year" || $dsp_t eq "epoch") &&
	($res eq "raw" || $res eq "hr"))
    {
	&err("Cannot do $res resolution over longer periods");
	return undef;
    }
	
    $url = sprintf("http://%WEBSRVR%%CGIPFX%/plot-all/%s,%s,%s,%s",
		   $intf, $dsp, $res, $in{"plot-type"});
    return $url;
}


#
# Main
#

$doc = new CGI;

&ReadParse();

if ($url = &check_input()) {
    print $doc->redirect($url);
}
exit(0);
