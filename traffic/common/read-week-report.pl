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
# Read a week report
#
# Output for traffic and traffic_kbit in global variables:
#  $intf{$intf}				enumerates logical port names
#  $busy_load_in{$intf, $tag}		input load, busy hour
#  $busy_load_out{$intf, $tag}		output load, busy hour
#  $peak_load_in{$intf, $tag}		input peak sample load
#  $peak_load_out{$intf, $tag}		output peak sample load
#  $average_load_in{$intf, $tag}	average input load
#  $average_load_out{$intf, $tag}	average output load
#  $ifspeed{$intf, $tag}		speed in kbit/s this week
#  $iftype{$intf, $tag}			interface type this week
#
# _load_ variables are either in kbit/s or percentage load depending
# on the type of report read.
#
# Output for error in global variables::
#  $intf{$intf}				enumerates logical port names
#  $errhrs_10{$intf, $tag}		error hours where inerr% > 1.0
#  $errhrs_01{$intf, $tag}		error hours where inerr% > 0.1
#  $errhrs_001{$intf, $tag}		error hours where inerr% > 0.01
#  $max_inerrs{$intf, $tag}		max day average input error %
#  $avg_inerrs{$intf, $tag}		week average input error %
#  $max_ignores{$intf, $tag}		max day average input ignore %
#  $avg_ignores{$intf, $tag}		week average input ignore %
#  $resets{$intf, $tag}			total week resets
#  $max_resets{$intf, $tag}		max day resets
#  $peak_discards{$intf, $tag}		peak hour output discard %
#  $max_discards{$intf, $tag}		max day average output discard %
#  $avg_discards{$intf, $tag}		week average output discard %
#  $iftype{$intf, $tag}			interface type this week
#

sub read_traffic {
    local($in, $tag) = @_;
    local($intf);

    while(<$in>) {
	chop;
	@_ = split;
	$intf = $_[0];
	$intf{$intf} = 1;
	$peak_load_in{$intf, $tag} = $_[1];
	$peak_load_out{$intf, $tag} = $_[2];
	$busy_load_in{$intf, $tag} = $_[3];
	$busy_load_out{$intf, $tag} = $_[4];
	$average_load_in{$intf, $tag} = $_[9];
	$average_load_out{$intf, $tag} = $_[10];
	$ifspeed{$intf, $tag} = $_[11];
	$iftype{$intf, $tag} = $_[12];
    }
}

sub read_traffic_kbit {
    local($in, $tag) = @_;
    local($intf);

    while(<$in>) {
	chop;
	@_ = split;
	$intf = $_[0];
	$intf{$intf} = 1;
	$peak_load_in{$intf, $tag} = $_[1];
	$peak_load_out{$intf, $tag} = $_[2];
	$busy_load_in{$intf, $tag} = $_[3];
	$busy_load_out{$intf, $tag} = $_[4];
	$average_load_in{$intf, $tag} = $_[7];
	$average_load_out{$intf, $tag} = $_[8];
	$ifspeed{$intf, $tag} = $_[9];
	$iftype{$intf, $tag} = $_[10];
    }
}

sub read_errors {
    local($in, $tag) = @_;
    local($intf);

    while(<$in>) {
	chop;
	@_ = split;
	$intf = $_[0];
	$intf{$intf} = 1;

	$errhrs_10{$intf, $tag} = $_[1];
	$errhrs_01{$intf, $tag} = $_[2];
	$errhrs_001{$intf, $tag} = $_[3];
	$max_inerrs{$intf, $tag} = $_[4];
	$avg_inerrs{$intf, $tag} = $_[5];
	$max_ignores{$intf, $tag} = $_[6];
	$avg_ignores{$intf, $tag} = $_[7];
	$resets{$intf, $tag} = $_[8];
	$max_resets{$intf, $tag} = $_[9];
	$peak_discards{$intf, $tag} = $_[10];
	$max_discards{$intf, $tag} = $_[11];
	$avg_discards{$intf, $tag} = $_[12];
	$iftype{$intf, $tag} = $_[13];
    }
}

1;
