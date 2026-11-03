Debian and Ubuntu packages for **Ritz**, the Tcl/Tk X11 client for the Zino
network monitor.

`ritz` depends on `tcl-tnm`, which is released separately from
[scotty-debian](https://github.com/Uninett/scotty-debian/releases). Install
both in a single `apt` invocation, or `apt` cannot resolve the dependency.

amd64 only in practice: `ritz` itself is `Architecture: all`, but it is
unusable without `tcl-tnm`, which is compiled and published for amd64 only.
