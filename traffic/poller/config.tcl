#
# $Id$
#

# Config file

cd %TOPDIR%

set confFile %TOPDIR%/conf/ifs.cf

# Scotty-delivered
mib load rfc1213.mib

# own
mib load "mibs/CISCO-SMI.my"
mib load "mibs/OLD-CISCO-INTERFACES-MIB.my"
