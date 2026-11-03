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

Add the apt repository (recommended, resolves dependencies for you):

```sh
curl -fsSL https://uninett.github.io/zino-apt/uninett-zino.asc \
  | sudo gpg --dearmor -o /usr/share/keyrings/uninett-zino.gpg
echo "deb [signed-by=/usr/share/keyrings/uninett-zino.gpg] \
https://uninett.github.io/zino-apt $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
  | sudo tee /etc/apt/sources.list.d/uninett-zino.list
sudo apt update && sudo apt install ritz
```

Or grab the `.deb`s from [Releases](../../releases) and install both at once,
since `ritz` needs `tcl-tnm`:

```sh
sudo apt install ./tcl-tnm_*.deb ./ritz_*.deb
```

Supported suites: Debian 13 (trixie) and Ubuntu 24.04 (noble), amd64.

## Related repositories

| | |
|---|---|
| [scotty-debian](https://github.com/Uninett/scotty-debian) | builds `tcl-tnm`, which supplies the Tnm Tcl extension Ritz requires |
| [zino-apt](https://github.com/Uninett/zino-apt) | the published apt repository |
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
