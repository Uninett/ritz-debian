#! /bin/sh

# $Id$

OUT=`mktemp /tmp/zm.XXXXXX`
PREVF="%TOPDIR%/zinomon-prev"

trap 0 "rm -f $OUT"

if [ ! -f $PREVF ]; then
    echo 0 > $PREVF
fi
PS=`cat $PREVF`

eval `%BINDIR%/emt-config`

send_sms_alarm () {
    subj="$1"

    if [ x"$emt_alarm_to" != x -a \
	 x"$emt_from" != x ]; then
	(
	    echo "To: $emt_alarm_to"
	    echo "From: $emt_from"
	    echo "Subject: $subj"
	    echo ""
	    echo "Failed to contact zino:"
	    cat $OUT
	) | %RAWSENDMAIL% -t
    fi
}


%PERL% -I %LIBDIR% %BINDIR%/zino-monitor.pl > $OUT 2>&1

es=$?

if [ $es != 0 -a $es != $PS ]; then
    echo $es > $PREVF
    if [ x"$emt_phones" != x ]; then
	for p in $emt_phones; do
	    send_sms_alarm "sms $p"
	done
    else
	if [ x"$emt_alarm_subject" != x ]; then
	    send_sms_alarm "$emt_alarm_subject"
	fi
    fi
fi
echo $es > $PREVF
