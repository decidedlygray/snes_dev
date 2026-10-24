# Dev notes

Raw material for future posts: snags, discoveries, ideas. Newest at the bottom.

## 2026-10-23: toolchain + hello world (→ post 001)

- Chose ca65/ld65 (only assembler with full Mesen debug support) and Mesen 2.1.1.
- Ubuntu 24.04 is the reference platform; Docker image reproduces it. macOS
  and Ubuntu builds are byte-identical (checksum `$A159`).
- cc65 2.19 calls itself "V2.18" on both Homebrew and Ubuntu.
- Mesen headless test runner gotchas: first-run wizard opens a window even
  headless (fix: portable `settings.json`); no controller plugged in by
  default (`--snes.port1.type=SnesController`); Lua io needs
  `--debug.scriptWindow.allowIoOsAccess=true`; Mesen `chdir`s to its home
  folder, so use absolute paths.
- macOS: Apple Silicon Mesen wants SDL2 at `/opt/homebrew/opt/sdl2`. My Mac
  has an Intel Homebrew (current) and an ARM Homebrew (stale), so the Intel
  Mesen build + Intel SDL2 under Rosetta was what worked. Possible short post:
  "two Homebrews on one Mac".
- Graphics as text art; the logo was generated from the font (2× scale,
  two-tone, drop shadow) by a throwaway script, then committed as text.
- Blink "PRESS START" by toggling its BG layer, with no VRAM writes. Nice
  example of thinking in PPU terms rather than "redraw the text".

## 2026-10-23: releases

- GitHub Actions builds and tests every push on Ubuntu 24.04 (same setup
  script), and pushing a `v*` tag publishes a Release with the ROM and its
  SHA-256. Because builds are reproducible, readers can rebuild a tag and
  check that they get the exact ROM I published.
- First CI run failed: the x86_64 Linux Mesen aborts with `std::bad_cast`
  at startup (arm64, which I'd tested on, was fine). I reproduced it in an
  amd64 Docker container on the Mac; `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`
  fixes it. Lesson: test on the architecture CI (and most readers) actually use.

## Ideas for later posts

- First boot on real hardware (EverDrive): photos, any differences from the emulator.
- How tiles, tilemaps and palettes actually work, using the VRAM viewer in Mesen.
- The 65816 register-width trap, with a deliberately broken example.
- Sprites (OAM) and a moving character.
- Sound: uploading a program to the SPC700; picking a music driver.
- From PNG to tiles: the art pipeline.
- Making the cartridge: PCB, CIC, flashing, shell.
