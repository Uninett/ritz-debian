#!%PERL%
#
# $Id$
#

# Copyright (c) 2002
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
push(@INC, "%LIBDIR%");

use strict;

require 'getopts.pl';
require 'perc-5m.pl';


sub usage {
    die "$0: usage: $0 [-N report-name] -d datespec -n (+-joined)portnames -p percentile";
}

#
# Main
#

our($opt_d, $opt_n, $opt_p);
our($opt_N, $opt_M);

&Getopts("d:MN:n:p:");

if (!defined($opt_d)) { &usage(); }
if (!defined($opt_n)) { &usage(); }
if (!defined($opt_p)) { &usage(); }

my($in, $out, $nd) = &get_percentile($opt_d, $opt_n, $opt_p);

if (defined($opt_M)) {		# Output in Mbit/s instead of kbit/s
    $in /= 1000;
    $out /= 1000;
}

if (!defined($opt_N)) {
    printf("%-15s %s (%d day%s) %s perc in %7.2f  out %7.2f (%s)\n",
	   $opt_n, $opt_d, $nd, $nd>1 ? "s" : "" , $opt_p, $in, $out,
	   $opt_M ? "Mbit/s" : "kbit/s"
	   );
} else {
    printf("%-15s %s (%d day%s) %s perc in %7.2f  out %7.2f (%s)\n",
	   $opt_N, $opt_d, $nd, $nd>1 ? "s" : "", $opt_p, $in, $out,
	   $opt_M ? "Mbit/s" : "kbit/s"
	   );
}
