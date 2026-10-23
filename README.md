# snes.dev

[![build](https://github.com/decidedlygray/snes_dev/actions/workflows/build.yml/badge.svg)](https://github.com/decidedlygray/snes_dev/actions/workflows/build.yml)

Super Nintendo homebrew written in 65816 assembly, developed in the open at
[snes.dev](https://snes.dev).

The current ROM is the toolchain proof of concept: a "snes.dev" studio logo,
a title screen, and a game that says "well, hello world!".

**Download:** ROMs are on the
[Releases page](https://github.com/decidedlygray/snes_dev/releases). Open
the `.sfc` in an emulator or copy it to a flash cart.

| Boot logo | Title screen | The "game" |
|---|---|---|
| ![logo](blog/images/001-logo.png) | ![title](blog/images/001-title.png) | ![hello](blog/images/001-hello.png) |

## Quick start (Ubuntu 24.04)

Ubuntu 24.04 is the reference platform: on bare metal, in a VM, or in Docker.

```sh
./tools/setup-ubuntu.sh   # cc65, make, Python 3 (apt) and Mesen 2.1.1
make                      # -> build/hello.sfc (+ hello.dbg symbols for Mesen)
make test                 # headless run in Mesen: checks every scene, saves screenshots
make run                  # play it in Mesen
```

### Any OS with Docker

```sh
make docker-test          # or: ./tools/docker-make.sh test
```

This builds an Ubuntu 24.04 image with the same setup script and runs `make`
inside it on this checkout. Output lands in `build/` as usual.

### macOS

```sh
brew install cc65 sdl2
```

Then install [Mesen 2](https://github.com/SourMesen/Mesen2/releases) into
`/Applications`. Mesen needs SDL2 from a Homebrew of the *same architecture*:
the Apple Silicon build looks in `/opt/homebrew`, the Intel build in
`/usr/local`. See [RESEARCH.md](RESEARCH.md#macos-notes) for details.

## Real hardware

`build/hello.sfc` is a plain headerless LoROM image. Copy it to a flash
cart's SD card (e.g. an EverDrive) and run it.

## Releases

GitHub Actions builds and tests every push. To publish a release, tag a
commit on `main` and push the tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The workflow ([.github/workflows/build.yml](.github/workflows/build.yml))
then builds the ROM on Ubuntu 24.04 and runs `make test`. If the test
passes, it publishes a release with `hello-v0.1.0.sfc` and its SHA-256
attached. Builds are reproducible, so `make` on the same tag produces
the same bytes. `make dist` creates the same files locally in `build/dist/`.

## Layout

```
src/        65816 assembly (ca65 syntax)
config/     ld65 linker memory map
assets/     graphics as text art, converted at build time
tools/      asset converter, checksum fixer, setup and Docker scripts
tests/      Mesen Lua smoke test
blog/       posts and notes for snes.dev (published separately)
RESEARCH.md everything learned so far, with sources
CLAUDE.md   project guide for the AI assistant
```
