#!%PERL%
#
# $Id$
#

# Copyright (c) 1997
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
# For some inexplicable reason the poller sometimes stops polling.
# This job detects such behaviour, kills the poller, restarts it and
# notifies the administrator(s) (%NOTIFY%) if such an event should occur.
#
# This job should be run once, and will keep on running forever,
# looping and doing this check every %CHECKINTV% seconds.
#


sub poller_pid {
    my($l, @a);

    if (defined(open(F, "%TOPDIR%/tpoller.pid"))) {
	$l = <F>;
	close(F);
    } else {
	open(PS, 'ps -axw | egrep 'sc\otty.*\./poller ' | sed -e "s/^ *//" |')
	    || return undef;
	$l = <PS>;
	close(PS);
    }
    if (!defined($l)) { return undef; }
    @a = split(/\s+/, $l);
    if (!defined($a[0]) || $a[0] !~ /[0-9]+/) { return undef; }
    return $a[0];
}

sub kill_poller {
    my($pid);

    if (defined($pid = &poller_pid())) {
	kill "TERM", $pid;
    }
}

sub start_poller {
    
    system("%BINDIR%/startup");
}

sub report_restart {
    my($subj);

    $subj = "Traffic poller restarted at `hostname`";

    open(MAIL, "| %MAIL% -s \"$subj\" %NOTIFY%") || return undef;
    printf(MAIL "ls output follows:\n\n");
    printf(MAIL "%s", $ls);
    close(MAIL);
}

sub report_start {
    my($subj);

    $subj = "Traffic poller started at `hostname`";
    
    system("%MAIL% -s \"$subj\" %NOTIFY% </dev/null");
}

sub restart_poller {

    &kill_poller();
    &start_poller();
    &report_restart();
}

# uses globals $ls and $oldls

sub check_poller {

    $oldls = $ls;
    $ls = "";
    open(LS, "ls -lt %DATADIR%/today |") || return undef;
    while(<LS>) {
	$ls .= $_;
    }
    close(LS);
    if ($ls eq $oldls) {
	&restart_poller();
    }
}

#
# Main
#

if (! defined(&poller_pid)) {
    &start_poller();
    &report_start();
    sleep(%CHECKINTV%);
}

while(1) {
    &check_poller();
    sleep(%CHECKINTV%);
}
