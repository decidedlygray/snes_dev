#!/usr/bin/env bash
# Install everything needed to build, run and test the ROM on Ubuntu 24.04
# (x86_64 or arm64, including an arm64 VM under UTM on Apple Silicon).
#
#   ./tools/setup-ubuntu.sh
#
# Installs the cc65 suite, make and Python from apt, and Mesen into
# ~/.local/opt/mesen with a `Mesen` launcher in ~/.local/bin.
set -euo pipefail

MESEN_VERSION=2.1.1
PREFIX="${PREFIX:-$HOME/.local}"

sudo=""
[ "$(id -u)" -ne 0 ] && sudo="sudo"

# The Linux build of Mesen is a .NET 8 app: it needs the .NET runtime and
# SDL2, plus fontconfig/X11 for its window (the headless test runner works
# without a display).
$sudo apt-get update
$sudo apt-get install -y --no-install-recommends \
    cc65 make python3 git curl unzip ca-certificates \
    dotnet-runtime-8.0 libsdl2-2.0-0 libfontconfig1 libx11-6 libice6 libsm6

case "$(uname -m)" in
    x86_64)        asset="Mesen_${MESEN_VERSION}_Linux_x64.zip" ;;
    aarch64|arm64) asset="Mesen_${MESEN_VERSION}_Linux_ARM64.zip" ;;
    *) echo "No Mesen build for $(uname -m)" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/mesen.zip" \
    "https://github.com/SourMesen/Mesen2/releases/download/${MESEN_VERSION}/${asset}"
mkdir -p "$PREFIX/opt/mesen" "$PREFIX/bin"
unzip -o -q "$tmp/mesen.zip" -d "$PREFIX/opt/mesen"
chmod +x "$PREFIX/opt/mesen/Mesen"

# Launcher. The x86_64 Linux build of Mesen 2.1.1 aborts at startup with
# "std::bad_cast" when .NET loads ICU for culture support (the arm64 build
# is fine), so turn that off; it doesn't affect emulation. Remove any old
# launcher first: if it's a symlink, writing to it would overwrite Mesen.
rm -f "$PREFIX/bin/Mesen"
cat > "$PREFIX/bin/Mesen" <<EOF
#!/bin/sh
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
exec "$PREFIX/opt/mesen/Mesen" "\$@"
EOF
chmod +x "$PREFIX/bin/Mesen"

# A settings.json next to the executable puts Mesen in portable mode: its
# config, saves and debugger files stay in $PREFIX/opt/mesen, and it skips
# the first-run wizard, which would otherwise open a window even in
# headless test-runner mode.
[ -f "$PREFIX/opt/mesen/settings.json" ] || echo '{}' > "$PREFIX/opt/mesen/settings.json"

echo
ca65 --version
echo "Mesen ${MESEN_VERSION} installed as $PREFIX/bin/Mesen"
case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) echo "Add $PREFIX/bin to your PATH (Ubuntu's ~/.profile does this at next login)." ;;
esac
