# Build environment for the ritz source package.
#
# The base image is a build argument so the same packaging can be built for
# every suite we ship to; see dev.sh's SUITE handling.
ARG BASE_IMAGE=debian:trixie
FROM ${BASE_IMAGE}

# We use BuildKit mount caches, so don't purge the apt cache after each command.
RUN rm -f /etc/apt/apt.conf.d/docker-clean; \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache

ENV DEBIAN_FRONTEND=noninteractive

# ritz is Architecture: all and needs no compiler; tk/tix/xvfb and the host
# tools it shells out to are here for the smoke test, not for the build.
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update && apt-get install -y \
      build-essential debhelper devscripts quilt fakeroot lintian \
      git git-buildpackage \
      tcl tk tix \
      xvfb xterm \
      curl ca-certificates vim less

RUN chmod 777 /home
ENV HOME=/home

# gbp runs git against the bind-mounted tree, which is owned by the invoking
# user and not by whoever runs in the container.
RUN git config --system --add safe.directory /work

CMD ["/bin/bash"]
