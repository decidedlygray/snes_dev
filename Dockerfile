# Ubuntu 24.04 build-and-test environment: cc65, make, Python and Mesen.
#
# It runs the same tools/setup-ubuntu.sh a reader would run in an Ubuntu VM,
# so "works in the container" means "works on Ubuntu". Normally used via
# tools/docker-make.sh (or `make docker-<target>`), e.g. `make docker-test`.

FROM ubuntu:24.04

COPY tools/setup-ubuntu.sh /tmp/setup-ubuntu.sh
RUN PREFIX=/usr/local /tmp/setup-ubuntu.sh \
    && chmod -R a+rwX /usr/local/opt/mesen

# The wrapper runs as your own user ID so build/ isn't owned by root; give
# that user (and .NET) a writable home.
ENV HOME=/tmp
WORKDIR /work
