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
# Read a day's worth of daily reports
#
# Output in:
#  $intf{$intf}				enumerates logical interface names
#  $busy_load_in{$intf, $yyyymmdd}	input load, busy hour
#  $busy_load_out{$intf, $yyyymmdd}	output load, busy hour
#  $peak_load_in{$intf, $yyyymmdd}	input peak sample load
#  $peak_load_out{$intf, $yyyymmdd}	output peak sample load
#  $average_load_in{$intf, $yyyymmdd}	average input load
#  $average_load_out{$intf, $yyyymmdd}	average output load
#  $ifspeed{$intf, $yyyymmdd}		speed in kbit/s this day
#  $iftype{$intf, $yyyymmdd}		interface type this day
#
# _load_ variables are either in kbit/s or percentage load depending
# on the type of report read.
#
# Output from read_error() in:
#  $intf{$intf, $yyyymmdd}		enumerates logical interface names
#  $inerr_10_hrs{$intf, $yyyymmdd}	hours with error % above 1.0
#  $inerr_01_hrs{$intf, $yyyymmdd}	hours with error % above 0.1
#  $inerr_001_hrs{$intf, $yyyymmdd}	hours with error % above 0.01
#  $inerrs{$intf, $yyyymmdd}		input error % avergaged over day
#  $ignores{$intf, $yyyymmdd}		ignore % averaged over day
#  $resets{$intf, $yyyymmdd}		count of resets over day
#  $discards{$intf, $yyyymmdd}		discard % averaged over day
#  $pk_discards{$intf, $yyyymmdd}	discard % in peak hour
#  $iftype{$intf, $yyyymmdd}		interface type


sub read_traffic {
    my($in, $yyyymmdd) = @_;
    my($intf);

    while(<$in>) {
	chop;
	@_ = split;
	$intf = $_[0];
	$intf{$intf} = 1;
	$busy_load_in{$intf, $yyyymmdd} = $_[1];
	$busy_load_out{$intf, $yyyymmdd} = $_[3];
	$peak_load_in{$intf, $yyyymmdd} = $_[5];
	$peak_load_out{$intf, $yyyymmdd} = $_[7];
	$average_load_in{$intf, $yyyymmdd} = $_[9];
	$average_load_out{$intf, $yyyymmdd} = $_[10];
	$ifspeed{$intf, $yyyymmdd} = $_[11];
	$iftype{$intf, $yyyymmdd} = $_[12];
    }
}

sub read_traffic_kbit {
    my($in, $yyyymmdd) = @_;
    my($intf);

    while(<$in>) {
	chop;
	@_ = split;
	$intf = $_[0];
	$intf{$intf} = 1;
	$busy_load_in{$intf, $yyyymmdd} = $_[1];
	$busy_load_out{$intf, $yyyymmdd} = $_[2];
	$peak_load_in{$intf, $yyyymmdd} = $_[3];
	$peak_load_out{$intf, $yyyymmdd} = $_[4];
	$average_load_in{$intf, $yyyymmdd} = $_[5];
	$average_load_out{$intf, $yyyymmdd} = $_[6];
	$ifspeed{$intf, $yyyymmdd} = $_[7];
	$iftype{$intf, $yyyymmdd} = $_[8];
    }
}

sub read_errors {
    my($in, $yyyymmdd) = @_;
    my($intf);

    while(<$in>) {
	chop;
	@_ = split;
	$intf = $_[0];
	$intf{$intf} = 1;
	$inerr_10_hrs{$intf, $yyyymmdd} = $_[1];
	$inerr_01_hrs{$intf, $yyyymmdd} = $_[2];
	$inerr_001_hrs{$intf, $yyyymmdd} = $_[3];
	$inerrs{$intf, $yyyymmdd} = $_[4];
	$crcerrs{$intf, $yyyymmdd} = $_[5];
	$frmerrs{$intf, $yyyymmdd} = $_[6];
	$aborts{$intf, $yyyymmdd} = $_[7];
	$ignores{$intf, $yyyymmdd} = $_[8];
	$resets{$intf, $yyyymmdd} = $_[9];
	$discards{$intf, $yyyymmdd} = $_[10];
	$pk_discards{$intf, $yyyymmdd} = $_[11];
	$iftype{$intf, $yyyymmdd} = $_[12];
    }
}

1;
