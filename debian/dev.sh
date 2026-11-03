#!/bin/sh -e
#
# Build the build-image for one target suite and run a command (or an
# interactive shell) in it, with this repository mounted at /work.
#
#   ./debian/dev.sh                       # interactive shell on the default suite
#   ./debian/dev.sh ./debian/ci-build.sh  # run a command
#   SUITE=ubuntu:24.04 ./debian/dev.sh    # pick another target suite
#   NONINTERACTIVE=1 ./debian/dev.sh ...  # no TTY prompt (for scripts/CI)
#   AS_ROOT=1 ./debian/dev.sh ...         # run as root (needed to install/test debs)
#
# ritz depends on tcl-tnm, which is built from the separate scotty-debian
# repository. Its build output is mounted read-only at /tnm so the smoke test
# can install it; point TNM_DEB_DIR elsewhere if yours lives somewhere else.
#
SUITE="${SUITE:-debian:trixie}"
SUITE_TAG="$(echo "$SUITE" | tr ':/' '--')"
TAG="ritz-debdev:$SUITE_TAG"
cd "$(dirname "$0")/.."

TNM_DEB_DIR="${TNM_DEB_DIR:-$PWD/../scotty-debian/build/$SUITE_TAG}"

if [ -n "$NONINTERACTIVE" ]; then TTYARGS="--tty"; else TTYARGS="--tty --interactive"; fi
if [ -n "$AS_ROOT" ]; then USERARGS=""; else USERARGS="--user $(id -u):$(id -g)"; fi
if [ -d "$TNM_DEB_DIR" ]; then
    TNMARGS="--volume $TNM_DEB_DIR:/tnm:ro"
else
    echo "note: $TNM_DEB_DIR does not exist; the smoke test will have no tcl-tnm" >&2
    TNMARGS=""
fi

DOCKER_BUILDKIT=1 docker build -t "$TAG" --build-arg "BASE_IMAGE=$SUITE" -f debian/Dockerfile .

exec docker run --rm $TTYARGS $USERARGS $TNMARGS \
    --volume "$PWD:/work" \
    --workdir /work \
    --env "SUITE_TAG=$SUITE_TAG" \
    --env "HOST_UID=$(id -u)" --env "HOST_GID=$(id -g)" \
    --env "DEBEMAIL=${DEBEMAIL:-morten.brekkevold@sikt.no}" \
    --env "DEBFULLNAME=${DEBFULLNAME:-Morten Brekkevold}" \
    "$TAG" "$@"
