#!/usr/bin/env python3
"""Patch the internal header checksum of a LoROM .sfc image, in place.

The checksum is the 16-bit sum of every byte in the ROM, and the complement
is checksum XOR $FFFF. Because the header itself is part of the sum, the
fields are first set to $FFFF/$0000 (which together add the same amount as
any valid checksum/complement pair) and then filled in.

Emulators only warn about a bad checksum, but some flash carts and copiers
use it to detect the ROM type, so we always get it right.

Reference: https://snes.nesdev.org/wiki/ROM_header#Checksum
"""

import sys
from pathlib import Path

HEADER = 0x7FC0             # LoROM: $00:FFC0
ROM_SIZE = HEADER + 0x17    # $FFD7: log2(size in KiB)
COMPLEMENT = HEADER + 0x1C  # $FFDC
CHECKSUM = HEADER + 0x1E    # $FFDE


def main():
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} ROM.sfc")
    path = Path(sys.argv[1])
    rom = bytearray(path.read_bytes())

    size = len(rom)
    if size < 0x8000 or size & (size - 1):
        sys.exit(f"{path}: size {size} is not a power of two of at least 32 KiB")
    declared = 1024 << rom[ROM_SIZE]
    if declared != size:
        sys.exit(f"{path}: header says {declared} bytes but the file is {size}")

    rom[COMPLEMENT:CHECKSUM + 2] = b"\xff\xff\x00\x00"
    checksum = sum(rom) & 0xFFFF
    rom[COMPLEMENT:COMPLEMENT + 2] = (checksum ^ 0xFFFF).to_bytes(2, "little")
    rom[CHECKSUM:CHECKSUM + 2] = checksum.to_bytes(2, "little")
    path.write_bytes(rom)

    title = rom[HEADER:HEADER + 21].decode("ascii", "replace").rstrip()
    print(f"fix_checksum: {path}: \"{title}\", {size // 1024} KiB, checksum ${checksum:04X}")


if __name__ == "__main__":
    main()
