# Research log

Running record of what's been learned while building this project: facts
with sources, decisions with reasons, and open questions. Newest log entries
at the bottom of each section. Dates are when the research was done.

**Primary references**

- SNESdev Wiki: https://snes.nesdev.org/wiki/SNESdev_Wiki (hardware, tools, init code)
- SNES Central homebrew list: https://snescentral.com/homebrew.php
- SNES Central development links: https://snescentral.com/development.php
  (a links page: undisbeliever's snesdev.net, the Wikibooks "Super NES
  Programming" book, the SNESdev forum on nesdev.org; it also points to the
  PCB/chip archives for cartridge hardware)
- PVSnesLib: https://github.com/alekmaul/pvsneslib

---

## 1. Host platform (2026-10-23)

**Decision: Ubuntu 24.04 LTS is the reference platform. macOS also works.
Docker is used to reproduce the Ubuntu setup anywhere.**

- Everything needed is cross-platform: the cc65 suite (assembler + linker),
  GNU Make, Python 3, and Mesen. No cross-compiler build is needed, because
  ca65 *is* the cross toolchain.
- Ubuntu 24.04's `universe` archive has `cc65` 2.19 and `dotnet-runtime-8.0`
  (needed by Mesen's Linux build) for both amd64 and arm64. Setup is one
  script: `tools/setup-ubuntu.sh`.
- The owner can run Ubuntu in a UTM VM on the MacBook. Use an **arm64**
  Ubuntu guest (native speed); x86_64 guests are fully emulated and slow.
  Mesen has a Linux ARM64 build.
- The Docker image (`Dockerfile`) runs the same setup script and is used for
  headless builds/tests. Verified on Docker Desktop (aarch64) on 2026-10-23:
  `make test` passes.
- **Builds are byte-identical** on macOS (Homebrew cc65) and Ubuntu (apt
  cc65): same 32 KiB ROM, checksum `$A159` at the time of writing.
- Windows: cc65 and Mesen both have Windows builds, but Make/Python/bash
  scripts are easiest under WSL2 with Ubuntu 24.04 (untested).

### macOS notes

- `brew install cc65` installs 2.19 (the binary reports itself as
  "V2.18"; Ubuntu's 2.19-1 package does the same, so it's upstream's version
  string).
- **Mesen needs SDL2 from a Homebrew of the same CPU architecture.**
  - The Apple Silicon build's core library links
    `/opt/homebrew/opt/sdl2/lib/libSDL2-2.0.0.dylib`, so it needs ARM Homebrew's `sdl2`.
  - The Intel build works with Intel Homebrew's `sdl2` in `/usr/local`
    (runs under Rosetta).
  - On the owner's Mac, the Intel build plus `/usr/local` SDL2 passes
    `make test`. The ARM build fails, because the ARM Homebrew is stale and
    has no SDL2.
  - Note: Homebrew's `sdl2` is now `sdl2-compat` (SDL2 API on top of SDL3).
- Mesen keeps its files in `~/Library/Application Support/Mesen2` (it
  extracts `MesenCore.dylib` there on every launch).

## 2. Assembler / toolchain (2026-10-23)

**Decision: ca65 + ld65 from the cc65 suite.**

| Option | What it is | Notes |
|---|---|---|
| **ca65/ld65** (cc65 2.19) | Macro assembler + linker | The wiki lists it among the most popular; **only ca65 has full debugging support in Mesen** (source-level, via ld65's `.dbg` file). Linker configs make memory maps explicit. Packaged in apt and Homebrew. libSFX builds on it. |
| 64tass | Assembler | Popular. |
| asar | Assembler | Popular, especially for ROM hacking (patching existing ROMs). |
| WLA-DX | Multi-CPU assembler/linker | Mature. PVSnesLib's toolchain is built on it. |
| bass, xkas-plus, snescom, TASM | Assemblers | Less common. |
| **PVSnesLib** | C SDK: 816-tcc compiler + libraries for backgrounds, sprites, input and sound | MIT; prebuilt for Windows, Linux and macOS; supports HiROM/FastROM; can be used from pure assembly. A good reference for how things are done and a fallback if C is ever wanted. Not used: this project is assembly-only. |
| libSFX | ca65 framework (macros, init, tools) | Worth reading for patterns. |
| Calypsi, vbcc, WDCTools | C compilers | Some are commercial for some uses. |

Source: https://snes.nesdev.org/wiki/Tools

ca65 specifics learned:

- String constants need `.define TITLE "..."`; `TITLE = "..."` is a syntax error.
- `.res count, fill` pads; `.strlen()` works on string literals and `.define`s.
- `--create-dep file.d` writes a Makefile dependency list (includes and incbins).
- `--bin-include-dir DIR` is the search path for `.incbin`.
- ca65 can't see `rep`/`sep`; `.a8/.a16/.i8/.i16` must match the CPU flags
  (handled by the macros in `src/macros.inc`). `.smart` mode exists but isn't used.
- `.global` exports a symbol where it's defined and imports it elsewhere;
  `.globalzp` is the same with direct-page addressing.

## 3. Emulators (2026-10-23)

**Decision: Mesen 2 (2.1.1, released 2025-07-06) for development and
automated testing. Cross-check in another accurate emulator before hardware
milestones.**

| Emulator | Notes |
|---|---|
| **Mesen 2** | The wiki says it "has the most features". Full debugger with ca65 symbols, Lua scripting, headless test runner. Builds: Windows, Linux x64/ARM64, macOS x64/ARM64. https://www.mesen.ca/, https://github.com/SourMesen/Mesen2/releases |
| bsnes-plus | Debugger fork of bsnes. |
| no$sns | Windows debugger. |
| bsnes / ares | Accuracy references (ares is in Homebrew as the `ares-emulator` cask, v148). Good second opinion. |
| Snes9x | Popular, less accurate; worth a check because many players use it. |

### Mesen test runner (from reading the 2.1.1 source + experiments)

- `Mesen --testRunner script.lua rom.sfc` runs headless (no Avalonia UI)
  at maximum speed. `emu.stop(code)` ends the run, and `code` becomes the
  process exit code. `--timeout=N` (seconds, default 100) is a backstop.
  `--enableStdout` sends `print()`/log output to stdout.
- **First-run wizard:** if there's no `settings.json` in Mesen's home
  folder, Mesen opens its setup wizard window even in test-runner mode. On a
  headless box that crashes ("XOpenDisplay failed"). Fix: a `settings.json`
  next to the executable switches Mesen to **portable mode** (home = exe
  folder), and `{}` is enough. `tools/setup-ubuntu.sh` does this.
- **Command-line config:** `--section.property=value` sets any config
  property (case-insensitive path into Mesen's config object), and
  `--doNotSaveSettings` makes it apply to this run only. Used:
  - `--snes.port1.type=SnesController`: with a bare config, **no
    controller is plugged in** (defaults are only written by the wizard), so
    `emu.setInput` silently does nothing.
  - `--debug.scriptWindow.allowIoOsAccess=true`: Lua's `io`/`os` libraries
    are disabled by default.
- Mesen changes its working directory to its home folder at startup, so
  scripts must use absolute paths (the Makefile passes `SCREENSHOT_DIR`).
- Mesen auto-loads the ca65 `.dbg` file sitting next to the ROM, so
  `emu.getLabelAddress("frame_count")` works (returns `{address, memType}`).
- Lua API bits used:
  - Events: `emu.eventType.{nmi, irq, startFrame, endFrame, reset, scriptEnded, inputPolled, stateLoaded, stateSaved, codeBreak}`.
  - Input: `emu.setInput({start=true}, port)`. Call it from an
    `inputPolled` callback, which fires right after Mesen refreshes the
    controller state each frame. Button names: `a b x y l r start select up down left right`.
  - Memory: `emu.read16(addr, emu.memType.snesVideoRam)`. VRAM is addressed
    in bytes here, so use word address × 2. Other types: `snesWorkRam`, `snesCgRam`, …
  - State: `emu.getState()` is a flat table, e.g. `["ppu.forcedBlank"]`,
    `["ppu.screenBrightness"]`, `["ppu.mainScreenLayers"]`,
    `["ppu.layers[0].tilemapAddress"]`.
  - `emu.takeScreenshot()` returns PNG bytes.
- Linux build: one self-contained `Mesen` binary that needs the .NET 8
  runtime (`dotnet-runtime-8.0`) and SDL2. Native libraries are extracted
  into the home folder at startup.

Source files read: `Core/Debugger/LuaApi.cpp`, `Core/Debugger/ScriptingContext.cpp`,
`Core/Shared/BaseControlManager.cpp`, `UI/Program.cs`, `UI/Utilities/CommandLineHelper.cs`,
`UI/Config/ConfigManager.cs`, `UI/Config/Configuration.cs`, `UI/Config/SnesConfig.cs`
at tag 2.1.1 of https://github.com/SourMesen/Mesen2.

## 4. Hardware facts used so far (2026-10-23)

### Memory map (LoROM)

- ROM appears in the upper half ($8000-$FFFF) of each bank, 32 KiB per bank.
  The CPU starts in bank $00, and all vectors point into bank $00.
- The first 8 KiB of WRAM ($0000-$1FFF) and the hardware registers
  ($2100-$21FF, $4200-$43FF) appear in banks $00-$3F and $80-$BF, so bank-$00
  code reaches them with 16-bit addresses when DBR = $00.
- All 128 KiB of WRAM is at $7E:0000-$7F:FFFF.

### Internal header ($00:FFB0-$00:FFDF, file offset $7FB0)

Source: https://snes.nesdev.org/wiki/ROM_header

| Addr | Size | Field |
|---|---|---|
| $FFB0 | 16 | Expanded header (maker code, game code, …); only valid if $FFDA = $33 |
| $FFC0 | 21 | Title, ASCII, space-padded |
| $FFD5 | 1 | Map mode `%001smmmm`: s = FastROM, m = 0 LoROM / 1 HiROM / 5 ExHiROM … |
| $FFD6 | 1 | Chipset: $00 ROM, $01 ROM+RAM, $02 ROM+RAM+battery, high nibble = coprocessor |
| $FFD7 | 1 | ROM size: 1 << N KiB ($05 = 32 KiB, $08 = 256 KiB) |
| $FFD8 | 1 | RAM size: 1 << N KiB (0 = none) |
| $FFD9 | 1 | Region: $00 Japan, $01 North America, $02 Europe … ($00/$01 NTSC, most others PAL) |
| $FFDA | 1 | Developer ID ($33 = expanded header present) |
| $FFDB | 1 | Version |
| $FFDC | 2 | Checksum complement (= checksum XOR $FFFF) |
| $FFDE | 2 | Checksum: 16-bit sum of all ROM bytes, computed with these four bytes set to $FF $FF $00 $00 |

The ROM should be a power-of-two size (non-power-of-two sizes have a
mirroring rule, and emulators disagree on it).

### Vectors ($00:FFE0-$00:FFFF)

Source: https://snes.nesdev.org/wiki/CPU_vectors

Native: COP $FFE4, BRK $FFE6, ABORT $FFE8 (unused on the SNES), NMI $FFEA,
IRQ $FFEE. Emulation: COP $FFF4, ABORT $FFF8, NMI $FFFA, RESET $FFFC,
IRQ/BRK $FFFE. Vectors are 16-bit, and the handlers run in bank $00. The CPU
always resets into emulation mode.

### Init sequence

Source: https://snes.nesdev.org/wiki/Init_code

1. `sei`, `clc`/`xce` (native mode). Then 8-bit A and 16-bit X/Y, stack
   pointer, D = 0, DBR = program bank.
2. Disable NMITIMEN/HDMAEN, then INIDISP = $8F (forced blank).
3. Clear WRAM with two 64 KiB fixed-source DMAs to WMDATA ($2180). This
   must be **inline in the reset handler**, before any `jsr`, because it
   wipes the stack.
4. Reset PPU registers (reusable routine). Notable values: VMAIN $80,
   BGnVOFS = $FF written twice (scroll -1), Mode 7 matrix identity
   (M7A/M7D = $0100), CGWSEL $30, COLDATA $E0, WRIO $FF, MEMSEL 0 (1 for FastROM).
5. Clear VRAM and CGRAM with fixed-source DMA. Move all sprites off-screen
   in OAM.

### PPU basics used by the hello-world ROM

- Screen is 256×224 (NTSC). With vertical scroll -1, tilemap rows 0-27 are
  exactly the visible rows (the PPU never shows scanline 0).
- **VRAM:** 64 KiB, addressed in 16-bit **words** ($0000-$7FFF).
  - Write via VMADDL/H + VMDATAL/H. With VMAIN = $80, the address advances
    after the high-byte write.
  - BGnSC value = `(word_addr >> 8) & $FC` (1 KiW steps).
  - BG12NBA = `(bg2_base >> 12) << 4 | (bg1_base >> 12)` (4 KiW steps).
- **Mode 0:** four BG layers, all 2bpp (4 colors). In this mode each BG
  has its own 8 palettes: BG1 uses CGRAM 0-31, BG2 32-63, BG3 64-95, BG4 96-127.
- **2bpp tile:** 16 bytes, two bytes per row (plane 0, plane 1), leftmost
  pixel in bit 7.
- **Tilemap entry** (16-bit): `vhopppcc cccccccc`. Bits: v/h flip,
  o priority, ppp palette, c = 10-bit tile number.
- **CGRAM:** 256 colors, 15-bit BGR555 (`0bbbbbgg gggrrrrr`), written low
  byte then high byte via CGDATA. Color 0 of each palette is transparent,
  and CGRAM 0 is the backdrop.
- **Access rule:** VRAM/CGRAM/OAM may only be written during vblank or
  forced blank (INIDISP bit 7). Brightness is INIDISP bits 0-3, and fades
  are just stepping it once or twice per frame.
- **NMI** fires at the start of vblank (scanline 225) when NMITIMEN bit 7 is
  set. Read RDNMI ($4210) to acknowledge it.
- **Auto-joypad read** (NMITIMEN bit 0) runs at the start of vblank for
  about 3 scanlines. Wait for HVBJOY bit 0 to clear before reading
  JOY1L/JOY1H. The 16-bit JOY1 value is `B Y Sel St U D L R | A X L R 0 0 0 0`.
- **DMA** channel registers are at $43x0-$43x6. To fill memory, point a
  fixed-source DMA (DMAP bit 3) at a zero byte in ROM. Mode 1 (two
  registers) suits VMDATAL/H; mode 0 suits CGDATA and WMDATA.

## 5. Real hardware and cartridges (2026-10-23)

### EverDrive (owner has one; model not yet recorded)

- Krikzz Super EverDrive X5/X6: ROMs up to 7.5 MB, save RAM up to 128 KB,
  FAT32 SD card. Retailer listing:
  https://dragonbox.de/en/everdrives-flashcarts/snes-super-everdrive-x6
- Use headerless `.sfc` files (the 512-byte copier header is obsolete). See
  https://snes.nesdev.org/wiki/ROM_file_formats. Our build output is headerless.
- Not yet tested on hardware. Things to watch: whether the 32 KiB ROM size
  is accepted (if not, pad to 256 KiB and set $FFD7 = $08), and how the
  region/timing match the owner's console.

### Making a physical cartridge (initial survey)

A cartridge needs a PCB with ROM (EPROM or flash) wired for the right map
mode (LoROM here), plus a **CIC lockout chip** (or a clone: some boards use
a programmed PIC microcontroller), and a shell.

- **Flashable repro boards**: e.g. the RetroCircuits SNES flash cart. It is
  flashed with the developer's programmer, and its CIC is a Microchip
  PIC10F322 that must be programmed (e.g. with a PICkit 4).
  https://www.pcbway.com/project/shareproject/Snes_Flash_cart_by_RetroCircuits_dc8cc488.html
- **EPROM repro boards**: e.g. pre-assembled M27C160/M27C322 boards (need an
  EPROM programmer). https://www.tindie.com/products/amperesand/m27c322-pre-assembled-repro-pcb-snes-homebrew-snes/
- **Open Source Cartridge Reader (OSCR, based on sanni's cart reader)**:
  dumps carts and can **write ROMs to flashable cartridges**. HW5 includes
  a clock generator and snesCIC.
  https://www.tindie.com/products/devdavisnunez/sanni-open-source-cartridge-reader-oscr-hw5-rev5/
  (project: https://github.com/sanni/cartreader)
- Retrode3 (based on sanni's design) advertises flash-cart writing, but its
  software was still in progress at the time.
- Shells and homebrew production services: e.g. https://dragonbox.de/en-de/homebrew-production
- Current availability and prices weren't verified. Revisit when the game is
  close to done.

## 6. Graphics pipeline

- **Now:** text-art assets converted by `tools/txt2chr.py` (no dependencies,
  diff-friendly, editable by hand or by AI). Supports 2bpp only.
- **Later, for real art:** SuperFamiconv (https://github.com/Optiroc/SuperFamiconv)
  converts PNGs to tiles, palettes and maps. Also see tiledpalettequant
  (browser palette reducer) and the M1TE2/M8TE/SPEZ editors by nesdoug.
  Source: https://snes.nesdev.org/wiki/Tools

## 7. Audio (not started)

Candidates from the wiki tools page: Terrific Audio Driver (music driver +
MML), SNES GSS (tracker + driver), Furnace (tracker). The SPC700 sound CPU
needs its own program uploaded at boot.

## Open questions

- [ ] Run `build/hello.sfc` on the EverDrive + console; record the EverDrive model and console region.
- [ ] NTSC or PAL console? This affects the header region byte and frame-based timings (60 vs 50 Hz).
- [ ] FastROM: not needed yet. If ever needed: map mode $30, MEMSEL = 1, code in banks $80+, `jml` there at reset.
- [ ] Pick a second accuracy-focused emulator for cross-checks (ares or bsnes).
- [ ] Cartridge route (flash vs. EPROM board, CIC, programmer). Decide when closer to release.
