#!/bin/sh
#
# $Id$
#

cd /tftpboot

CF=${HOME}/.zino-mail
if [ ! -f $CF ]; then
    echo "No $CF file" >&2
    exit 1
fi

source $CF

if test -s last-checked-diff ; then
    (
    echo "To: ${MAILTO}";
    echo "From: ${MAILFROM}";
    echo "Subject: Device config changes `date +%y-%m-%d`";
    echo "";
    cat last-checked-files last-checked-diff;
    ) | %RAWSENDMAIL% ${MAILTO}

    cat last-checked-files last-checked-diff > last-checked-diff.`date +%a`
    rm  last-checked-files last-checked-diff
fi
