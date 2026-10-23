# CLAUDE.md

Guide for AI assistants working in this repository.

## What this is

An SNES (Super Nintendo) homebrew game written in **65816 assembly**,
developed live and written about on the owner's blog, **snes.dev**. The
current ROM is a proof of concept: studio logo → title screen ("PRESS
START") → a screen that says "well, hello world!". The actual game design
(gameplay, art style) is still undecided, so don't invent game features
unless asked.

Targets, in order: Mesen (emulator) → EverDrive flash cart on a real SNES →
eventually a flashed reproduction cartridge.

## Ground rules

- **Assembly only** (ca65 syntax). No C, no PVSnesLib, unless the owner
  changes this.
- **`blog/` is content, not a website.** Write and update Markdown there, but
  never publish, deploy or post anything. The owner posts to snes.dev
  separately. Readers are developers following along; posts are in the
  owner's voice (first person).
- **When something post-worthy happens** (a hard bug, a surprising hardware
  quirk, a tooling snag), add a short dated entry to `blog/notes.md`.
- **Research goes in `RESEARCH.md`**: facts with sources, decisions with
  reasons, open questions. Check it before re-researching something, and
  add to it when you learn something new.
- Verify hardware facts against the SNESdev wiki
  (https://snes.nesdev.org/wiki/SNESdev_Wiki) rather than memory. "Works in
  the emulator" is not "works on hardware"; Mesen is accurate but the
  EverDrive is the real test.

## Commands

```sh
make               # build build/hello.sfc (+ .dbg symbols, .map)
make test          # headless Mesen run of tests/smoke.lua; exit 0 = pass
make run           # open in Mesen (interactive; the owner does this, not you)
make docker-test   # same as `make test` inside the Ubuntu 24.04 container
make dist          # build/dist/hello-<git describe>.sfc + .sha256
make clean
```

- Run `make test` (or `make docker-test`) after every change and before
  saying something works. It saves `build/screenshots/{1-logo,2-title,3-hello}.png`;
  **look at them** (Read the PNGs) after any visual change.
- When a scene changes, update `tests/smoke.lua` to match.
- Reference platform is Ubuntu 24.04. The Docker image (`Dockerfile`, built
  from `tools/setup-ubuntu.sh`) is the quickest way to check it. Builds are
  byte-identical on macOS and Ubuntu; keep it that way (no timestamps or
  host paths in the ROM).

## Layout

| Path | Contents |
|---|---|
| `src/snes.inc` | Hardware register names (SNESdev wiki spelling) and bit constants |
| `src/macros.inc` | `A8`/`A16`/`I8`/`I16`/`AXY8`/`AXY16`, `rgb`, `text_at`/`text_center` |
| `src/vram.inc` | VRAM layout and tilemap attribute bits |
| `src/globals.inc` | Cross-module `.global`s, `vram_copy`/`cgram_copy` macros |
| `src/header.s` | Internal header ($FFB0) and vectors ($FFE0) |
| `src/init.s` | Reset handler, WRAM clear, register reset |
| `src/video.s` | NMI handler, `wait_frame`, fades, DMA helpers, `draw_text_list` |
| `src/input.s` | `read_joypad` → `pad_held` / `pad_pressed` |
| `src/main.s` | Scenes and their data (text, palettes, `.incbin` graphics) |
| `config/lorom32k.cfg` | ld65 memory map (LoROM, 32 KiB, SlowROM) |
| `assets/*.txt` | Text-art graphics (font, logo) |
| `tools/txt2chr.py` | Text art → 2bpp tiles (+ tilemap) |
| `tools/fix_checksum.py` | Patches the header checksum after linking |
| `tools/setup-ubuntu.sh` | Installs toolchain + Mesen on Ubuntu 24.04 |
| `tools/docker-make.sh` | Runs `make <target>` in the container |
| `tests/smoke.lua` | Mesen test-runner script |

## Code conventions

- **Register widths:** between routines, A is 8-bit and X/Y are 16-bit
  (`.a8`/`.i16`). Every `.proc` starts with `.a8`/`.i16` directives so ca65
  knows the entry state, and returns in that state. Change widths only with
  the macros in `macros.inc` (they emit `rep`/`sep` *and* the matching
  directive). Remember `sep`/`rep` don't touch Z/N, and that 16-bit pushes
  need 16-bit registers at pop time too.
- **DBR = $00, D = $0000** always. Code and data live in bank $00 for now.
- **PPU access:** VRAM/CGRAM/OAM writes only in forced blank or vblank.
  Current pattern: scenes do all loading in forced blank (after `fade_out`),
  and the NMI handler only copies shadow registers (`inidisp_shadow`,
  `tm_shadow`). Keep the NMI handler short.
- **VRAM layout** is defined in `src/vram.inc`. `LOGO_TILE` is defined once in
  the Makefile and passed to both ca65 (`-D`) and the converter.
- **Text:** the font is loaded so tile number == ASCII code. Text lists are
  built with `text_at`/`text_center` and drawn with `draw_text_list`.
- Comments explain *why* and SNES-specific *what* (readers of the blog learn
  from this code). Match the existing density; don't narrate obvious lines.
- Register names follow the SNESdev wiki (`INIDISP`, `VMADDL`, `NMITIMEN`…).

## Assets

Graphics are text art, so they diff in git and can be edited directly.
Legend: `.` = color 0 (transparent), `#` = 1, `=` = 2, `:` = 3. `;` starts a
comment. Font: `glyph X` (or `glyph $NN`) followed by 8 rows of 8. Images:
a rectangle with sides that are multiples of 8. Colors are set in
`src/main.s`. For real art later, a PNG pipeline (e.g. SuperFamiconv) is the
likely next step; see RESEARCH.md.

## Environment gotchas

- **Owner's Mac** (Apple Silicon) has two Homebrews: an up-to-date Intel one
  in `/usr/local` (first on PATH, used for cc65 and SDL2) and a stale ARM one
  in `/opt/homebrew`. The Apple Silicon Mesen needs SDL2 from
  `/opt/homebrew`; the Intel Mesen build works with `/usr/local` SDL2. Don't
  modify either Homebrew without asking.
- On that Mac, GNU sed shadows BSD sed (`sed -i` takes no `''`), and there is
  no `timeout`. macOS ships GNU Make 3.81 (no `&:` grouped targets) and bash
  3.2 (empty arrays break under `set -u`). Keep the Makefile and scripts
  compatible with both these and Ubuntu's versions.
- Mesen pops up a GUI error dialog even in `--testRunner` mode if SDL2 is
  missing, or if it has no `settings.json` (first-run wizard). The owner will
  see those dialogs, so check dependencies before launching Mesen on the Mac.
- Mesen test runner details (switches, Lua API names, why the controller
  must be plugged in on the command line) are in RESEARCH.md → "Mesen".

## Git, CI and releases

- Remote: `git@github.com:decidedlygray/snes_dev.git` (public). The repo's
  `core.sshCommand` already points at the right SSH key, so plain
  `git push` works. Commit and push only when asked.
- `.github/workflows/build.yml` runs `make`, `make test` and `make dist` on
  Ubuntu 24.04 for every push to `main` and every PR, and uploads the ROM
  and screenshots as artifacts. Check a run's status with
  `curl -s https://api.github.com/repos/decidedlygray/snes_dev/actions/runs?per_page=1`
  (`gh` isn't installed on the owner's Mac).
- **Releases** are created by pushing a `vMAJOR.MINOR.PATCH` tag. The
  workflow's `release` job publishes the ROM and its SHA-256 to GitHub
  Releases. Releases are public, so only tag when the owner asks, and only
  on a commit whose CI run passed.
