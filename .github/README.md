# ritz-debian

Debian and Ubuntu packaging for **Ritz**, the Tcl/Tk X11 client for the Zino
network monitor. The packaging lives in [`debian/`](../debian) on the
`debian/latest` branch.

> **This repository also contains the full legacy Zino 1 source**, as its
> upstream history. Zino 1 has no public repository of its own, so this
> packaging repo doubles as its public home. That is why you see `zino/`,
> `emt/`, `traffic/` and friends at the top level.
>
> **This is not Zino 2.** The current Zino is [Uninett/zino](https://github.com/Uninett/zino),
> a separate Python implementation.

## Installing

There is no apt repository yet, so the packages are installed by hand. You need
two files, both built for the same distribution:

- `ritz_*_all.deb` from this repository's [Releases](../../releases)
- `tcl-tnm_*_amd64.deb` from
  [scotty-debian's Releases](https://github.com/Uninett/scotty-debian/releases)

Download both, then install them in a **single** `apt` command. Installing
`ritz` on its own fails, because `apt` has nowhere to resolve `tcl-tnm` from.

```sh
sudo apt install ./tcl-tnm_*.deb ./ritz_*.deb
```

`apt` pulls in `tk`, `tix`, `xterm`, `telnet` and `traceroute` from your own
archive. Each release page lists the exact filenames and their checksums.

### Fetching them without a browser

Set `SUITE` to `trixie` for Debian 13 or `noble` for Ubuntu 24.04. This asks
the Releases API for whatever the current version is, so there is no version
to keep up to date:

```sh
SUITE=trixie
for repo in scotty-debian ritz-debian; do
  curl -fsSL "https://api.github.com/repos/Uninett/$repo/releases/latest" \
  | grep -o "https://[^\"]*\.${SUITE}1_[^\"]*\.deb" \
  | grep -v dbgsym \
  | xargs -r -n1 curl -fsSLOJ
done
sudo apt install ./tcl-tnm_*.deb ./ritz_*.deb
```

Only amd64 is built. The `-J` matters: it takes the filename from the server
rather than from the URL, which would otherwise be percent-encoded.

## Related repositories

| | |
|---|---|
| [scotty-debian](https://github.com/Uninett/scotty-debian) | builds `tcl-tnm`, which supplies the Tnm Tcl extension Ritz requires |
| [Uninett/zino](https://github.com/Uninett/zino) | Zino 2, the current implementation (unrelated to this packaging) |

## Building it yourself

Needs Docker only. The build runs in a container matching the target suite:

```sh
./debian/build.sh                      # Debian trixie, into ./build/
SUITE=ubuntu:24.04 ./debian/build.sh   # another suite
./debian/smoke.sh                      # build, install and launch under Xvfb
```

## Layout

The repository follows the usual `gbp` fork layout: the packaging branch
carries upstream's history with `debian/` added on top, and `gbp buildpackage`
exports the orig tarball from the `upstream/*` tag. Upstream makes no releases,
so versions are snapshots of the form `1.0+gitYYYYMMDD.<sha>`.
