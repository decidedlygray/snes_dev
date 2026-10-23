#!/usr/bin/env python3
"""Convert text-art assets into SNES 2bpp tile data (and tilemaps).

Assets are plain text so they diff cleanly in git and can be edited by hand
(or by an AI assistant) with no image editor. Pixel legend:

    .  color 0 (transparent)
    #  color 1
    =  color 2
    :  color 3

Lines starting with ';' are comments; blank lines are ignored.

font mode
    A series of 8x8 glyphs. Each starts with a line "glyph X", where X is the
    character itself or $NN for a hex code (use $20 for space), followed by
    8 rows of 8 pixels. Writes one tile per character code from --first to
    --first + --count - 1; undefined characters become blank tiles.

image mode
    One picture whose width and height are multiples of 8. Writes the
    picture's unique tiles (--chr) and a full 32x32 tilemap (--tilemap) that
    places it centred on the visible 32x28-tile screen, or at --at COL,ROW.
    Fully transparent 8x8 cells use --blank-tile instead of a new tile.

SNES 2bpp tile format: 16 bytes per 8x8 tile, two bytes per row (bit plane
0, then bit plane 1), leftmost pixel in the most significant bit.
"""

import argparse
import sys
from pathlib import Path

LEGEND = {".": 0, "#": 1, "=": 2, ":": 3}
TILE = 8
MAP_W, MAP_H = 32, 32       # tilemap size in tiles
SCREEN_H = 28               # visible rows (224 lines) with vertical scroll -1


def die(message):
    sys.exit(f"txt2chr: {message}")


def art_lines(path):
    """(line number, text) for every line that isn't blank or a comment."""
    for number, raw in enumerate(Path(path).read_text().splitlines(), 1):
        line = raw.rstrip()
        if line and not line.startswith(";"):
            yield number, line


def parse_row(path, number, line, width=None):
    try:
        row = [LEGEND[c] for c in line]
    except KeyError as e:
        die(f"{path}:{number}: unknown pixel {e.args[0]!r} (legend: {' '.join(LEGEND)})")
    if width is not None and len(row) != width:
        die(f"{path}:{number}: expected {width} pixels, found {len(row)}")
    return row


def encode_2bpp(tile):
    """8 rows of 8 color indices -> 16 bytes of SNES 2bpp planar data."""
    out = bytearray()
    for row in tile:
        plane0 = plane1 = 0
        for x, color in enumerate(row):
            plane0 |= (color & 1) << (7 - x)
            plane1 |= (color >> 1) << (7 - x)
        out += bytes((plane0, plane1))
    return bytes(out)


def parse_font(path):
    lines = list(art_lines(path))
    glyphs = {}
    i = 0
    while i < len(lines):
        number, line = lines[i]
        if not line.startswith("glyph "):
            die(f"{path}:{number}: expected 'glyph X', found {line!r}")
        name = line[len("glyph "):]
        if len(name) == 1:
            code = ord(name)
        elif name.startswith("$"):
            code = int(name[1:], 16)
        else:
            die(f"{path}:{number}: glyph name must be one character or $NN, found {name!r}")
        if code in glyphs:
            die(f"{path}:{number}: glyph {name!r} defined twice")
        rows = lines[i + 1:i + 1 + TILE]
        if len(rows) < TILE:
            die(f"{path}:{number}: glyph {name!r} has fewer than {TILE} rows")
        glyphs[code] = [parse_row(path, n, row, TILE) for n, row in rows]
        i += 1 + TILE
    return glyphs


def font_mode(args):
    glyphs = parse_font(args.input)
    last = args.first + args.count
    for code in glyphs:
        if not args.first <= code < last:
            die(f"glyph ${code:02X} is outside --first/--count")
    blank = [[0] * TILE] * TILE
    chr_data = b"".join(encode_2bpp(glyphs.get(code, blank))
                        for code in range(args.first, last))
    Path(args.chr).write_bytes(chr_data)
    print(f"txt2chr: {args.input}: {len(glyphs)} glyphs -> {args.chr} ({len(chr_data)} bytes)")


def image_mode(args):
    rows = []
    for number, line in art_lines(args.input):
        rows.append(parse_row(args.input, number, line, len(rows[0]) if rows else None))
    if not rows:
        die(f"{args.input}: no pixels")
    width, height = len(rows[0]), len(rows)
    if width % TILE or height % TILE:
        die(f"{args.input}: size {width}x{height} is not a multiple of {TILE}")
    tiles_w, tiles_h = width // TILE, height // TILE

    tiles = []      # unique tile data, in VRAM order
    numbers = {}    # tile data -> tile number
    cells = []      # tile number for each 8x8 cell, row-major
    for ty in range(tiles_h):
        for tx in range(tiles_w):
            tile = [rows[ty * TILE + y][tx * TILE:(tx + 1) * TILE] for y in range(TILE)]
            if not any(any(row) for row in tile):
                cells.append(args.blank_tile)
                continue
            data = encode_2bpp(tile)
            if data not in numbers:
                numbers[data] = args.base_tile + len(tiles)
                tiles.append(data)
            cells.append(numbers[data])

    if args.at == "center":
        col, row = (MAP_W - tiles_w) // 2, (SCREEN_H - tiles_h) // 2
    else:
        col, row = (int(v) for v in args.at.split(","))
    if col < 0 or row < 0 or col + tiles_w > MAP_W or row + tiles_h > MAP_H:
        die(f"{args.input}: {tiles_w}x{tiles_h} tiles don't fit at {col},{row}")
    if args.base_tile + len(tiles) > 1024:
        die(f"{args.input}: tile numbers run past 1023")

    attr = (args.palette << 10) | (args.priority << 13)
    tilemap = [args.blank_tile] * (MAP_W * MAP_H)
    for ty in range(tiles_h):
        for tx in range(tiles_w):
            tile_number = cells[ty * tiles_w + tx]
            if tile_number != args.blank_tile:
                tile_number |= attr
            tilemap[(row + ty) * MAP_W + col + tx] = tile_number

    Path(args.chr).write_bytes(b"".join(tiles))
    Path(args.tilemap).write_bytes(b"".join(e.to_bytes(2, "little") for e in tilemap))
    print(f"txt2chr: {args.input}: {width}x{height} px, {len(tiles)} unique tiles "
          f"(#{args.base_tile}-#{args.base_tile + len(tiles) - 1}) at {col},{row} "
          f"-> {args.chr}, {args.tilemap}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="mode", required=True)

    font = sub.add_parser("font", help="8x8 glyph list -> tiles")
    font.add_argument("input")
    font.add_argument("--chr", required=True, help="output tile data")
    font.add_argument("--first", type=int, default=32, help="first character code (default 32)")
    font.add_argument("--count", type=int, default=96, help="number of tiles (default 96)")
    font.set_defaults(run=font_mode)

    image = sub.add_parser("image", help="picture -> unique tiles + 32x32 tilemap")
    image.add_argument("input")
    image.add_argument("--chr", required=True, help="output tile data")
    image.add_argument("--tilemap", required=True, help="output tilemap (2048 bytes)")
    image.add_argument("--base-tile", type=int, required=True,
                       help="VRAM tile number the first output tile will be loaded at")
    image.add_argument("--blank-tile", type=int, default=0,
                       help="tile number for empty cells (default 0)")
    image.add_argument("--palette", type=int, default=0, choices=range(8))
    image.add_argument("--priority", type=int, default=0, choices=(0, 1))
    image.add_argument("--at", default="center", help="COL,ROW of the top-left tile, or 'center'")
    image.set_defaults(run=image_mode)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
