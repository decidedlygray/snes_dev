#!/usr/bin/env bash
# Run make inside the Ubuntu 24.04 container (see Dockerfile), on this checkout.
#
#   ./tools/docker-make.sh            # make
#   ./tools/docker-make.sh test       # make test (headless Mesen)
#
# The image is built on first use and rebuilt when the Dockerfile or setup
# script changes (Docker's layer cache makes that check fast).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
image="snes-dev"

docker build --quiet --tag "$image" "$root" > /dev/null

tty=""
[ -t 1 ] && tty="--tty"     # (a plain string: macOS bash 3.2 dislikes empty arrays)

exec docker run --rm $tty \
    --user "$(id -u):$(id -g)" \
    --volume "$root:/work" \
    "$image" make "$@"
