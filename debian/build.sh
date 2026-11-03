#!/bin/sh -e
#
# Build ritz for one suite (default debian:trixie) into ./build/.
#
cd "$(dirname "$0")/.."
NONINTERACTIVE=1 ./debian/dev.sh ./debian/ci-build.sh
echo
echo "Packages are in $(pwd)/build/"
