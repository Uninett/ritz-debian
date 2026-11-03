#!/bin/sh -e
#
# Like build.sh, but runs as root inside the container so it can also install
# the freshly built .deb (plus tcl-tnm from /tnm) and launch ritz under Xvfb.
#
cd "$(dirname "$0")/.."
NONINTERACTIVE=1 AS_ROOT=1 ./debian/dev.sh ./debian/ci-build.sh
