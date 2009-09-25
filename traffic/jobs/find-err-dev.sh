#! /bin/sh
#
# $Id$
#

#
# Wrapper script around find_err_dev suitibale for use in a cron job.
# Reports the diff in the reports from find_deviation to STDOUT if
# it is non-empty
#
# Written by Thomas Adamcik 2008

REPORTS=$1

REPORTS=${REPORTS:='%TOPDIR%/reports/2*'}

COUNT=20  # Number of days to use

# Options for the two file types run
 # 'find_devation.pl --help' for more info
ERRS_PERC_OPTIONS="--previous=errors_perc.yaml --diff"
EERRS_PERC_OPTIONS="--previous=ether_errs_perc.yaml --diff"

EMAIL_TEXT="
Here follows a list of which logical ports have had statistically
significant changes since the previous report was generated.

The analyzed data can be viewed here:
  http://%WEBSRVR%/%HTMLPFX%/tbl-report.html
"

FIND_DEV="%TOPDIR%/bin/find-err-dev.pl"

## END CONFIG ##

# Find files to check limiting to count
ERRS_PERC_FILES=`find $REPORTS -name errors.perc | sort | tail -$COUNT`
EERRS_PERC_FILES=`find $REPORTS -name ether_errs.perc | sort |tail -$COUNT `

# Generate our new reports
ERRS_PERC_REPORT=`$FIND_DEV $ERRS_PERC_OPTIONS $ERRS_PERC_FILES`
# EERRS_PERC_REPORT=`$FIND_DEV $EERRS_PERC_OPTIONS $EERRS_PERC_FILES`

# Exit if there is nothing to report
[ -z "$ERRS_PERC_REPORT" -a -z "$ETHER_ERRS_PERC_REPORT" ] && exit

# Print nice informative message
cat<<EOF
$EMAIL_TEXT
errors.perc
===========
$ERRS_PERC_REPORT

EOF
