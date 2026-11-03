#!/bin/sh -e
#
# Runs *inside* the build container (see dev.sh). Builds the ritz package with
# gbp, which generates the orig tarball from the upstream/* tag recorded in
# debian/gbp.conf. If run as root, it also installs the result together with
# tcl-tnm from /tnm and launches ritz under Xvfb.
#
cd /work

# ritz is Architecture: all, but keeping the per-suite layout the scotty
# packaging uses means the two repositories' build trees look the same.
OUT="build/${SUITE_TAG:-debian-trixie}"

# AS_ROOT=1 runs as root against a bind-mounted tree, which would leave
# root-owned artifacts the invoking user cannot overwrite, breaking every
# later non-root build. Hand them back on the way out, however we exit.
if [ "$(id -u)" = 0 ] && [ -n "${HOST_UID:-}" ]; then
    trap 'chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" build 2>/dev/null || true' EXIT
fi

# gbp refuses to build from a tree with uncommitted changes unless told not to
# care; during development we usually do not care.
gbp buildpackage --git-ignore-new --git-ignore-branch --git-export-dir="$OUT" \
    --git-builder="debuild --no-lintian -i -I -us -uc"

echo "=== lintian (informational) ==="
lintian -I "$OUT"/*.deb "$OUT"/*.dsc || true

echo "=== built packages ==="
ls -1 "$OUT"/*.deb

if [ "$(id -u)" != 0 ]; then
    echo "(re-run via ./debian/smoke.sh to also install the .deb and X-test it)"
    exit 0
fi

echo "=== smoke test: install + launch under Xvfb ==="
if [ ! -d /tnm ]; then
    echo "SMOKE SKIPPED: no tcl-tnm build mounted at /tnm" >&2
    exit 1
fi
# /tnm accumulates every tcl-tnm ever built for this suite, so pick the
# highest version rather than globbing and handing apt several at once.
# (tcl-tnm-dbgsym_* does not match this glob: the underscore is significant.)
TNM_DEB=$(ls -v /tnm/tcl-tnm_*.deb 2>/dev/null | tail -1)
if [ -z "$TNM_DEB" ]; then
    echo "SMOKE FAILED: no tcl-tnm package in /tnm" >&2
    exit 1
fi
echo "using $TNM_DEB"

apt-get update
apt-get install -y "$TNM_DEB" "$PWD/$OUT"/ritz_*.deb

export HOME=/tmp/smoke
mkdir -p "$HOME"          # empty HOME => no ~/.ritz.tcl => no auto-connect
set +e
xvfb-run -a timeout 6 ritz
rc=$?
set -e
if [ "$rc" != 124 ]; then
    echo "SMOKE FAILED: ritz exited $rc (expected 124 = killed in mainloop)" >&2
    exit 1
fi
echo "SMOKE OK: ritz loaded Tix + Tnm and reached the Tk mainloop"
