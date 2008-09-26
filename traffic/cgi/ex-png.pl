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
# Serve a PNG image file with expiry time specified either as number of
# seconds offset from "now" or as "next period-type of expiry".
#

push(@INC, "%LIBDIR%");

use CGI;

require 'utils.pl';
require 'date.pl';

#
# Main
#

$doc = new CGI;

$pfx = "";
if ($ENV{'QUERY_STRING'}) {
    $query = $ENV{'QUERY_STRING'};
} elsif ($ENV{'PATH_INFO'}) {
    $query = $ENV{'PATH_INFO'};
    $query =~ s/^\///;
    $pfx = "../";
} else {
    $query = "@ARGV";
}

($exp, $refname) = split(/\s*,\s*/, "$query");

# Check arguments for syntactic validity
@al = ($exp, $refname);
if (defined($ai = &invalid_arg("[-A-Za-z0-9_./\+]*", @al))) {
    print $doc->header(-type => "text/html");
    printf("<h2>Invalid argument: %s</h2>\n", $al[$ai]);
    print $doc->end_html;
    print "\n";
    exit 1;
}

if ("%HTMLPFX%" ne "") {
    $ix = index(substr($refname, 1), "/");
    $bn = substr($refname, $ix+2);
} else {
    $bn = $refname;
}
$rfn = "%HTMLDIR%" . $refname;

if ($exp !~ /[0-9]+/) {
    $exp = &secs_to_expiry($exp);
}

if (! -f $rfn) {
    print $doc->header(-type => "text/html");
    print "<h2>Error</h2>\n";
    print "<pre>\n";
    printf("file \'$refname\'\n");
    printf("(really \'$rfn\') does not exist\n");

#    $| = 1;

#    print "\n\n";
#    system("env");
    
    print $doc->end_html;
    print "\n";
    exit(1);
}

select(STDOUT); $| = 1;

print $doc->header(-type => "image/png",
		   -expires => sprintf("+%ds", $exp));

open(IN, $rfn);
$bytes="";
while($n = sysread(IN, $bytes, 1024)) {
    syswrite(STDOUT, $bytes, $n);
}
close(IN);
exit(0);
