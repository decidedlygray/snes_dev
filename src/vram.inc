; vram.inc - where everything lives in VRAM, and tilemap attribute bits.
;
; VRAM is 64 KiB addressed in 16-bit words ($0000-$7FFF). All addresses here
; are word addresses, which is what VMADD and the BGxSC/BGxxNBA registers use.
;
;   $0000-$03FF  BG1 tilemap (32x32 entries)
;   $0400-$07FF  BG2 tilemap
;   $1000-$1FFF  BG1/BG2 tiles (2bpp = 8 words per tile, 512 tiles)
;                  tile 0-31    blank (tile 0 must stay blank: empty
;                               tilemap entries point at it)
;                  tile 32-127  font, so tile number == ASCII code
;                  tile 128+    logo (LOGO_TILE)

BG1_MAP  = $0000
BG2_MAP  = $0400
BG_CHR   = $1000

FONT_TILE = 32      ; first font tile = first printable ASCII character

; LOGO_TILE is passed in by the Makefile (-D LOGO_TILE=...) because the asset
; converter needs the same number to build the logo's tilemap.
.ifndef LOGO_TILE
    .error "LOGO_TILE is not defined; build with make"
.endif

; Tilemap entry high byte: vhopppcc
;   v/h = flip, o = priority, ppp = palette, cc = tile number bits 8-9
ATTR_PAL0 = 0 << 2
ATTR_PAL1 = 1 << 2
ATTR_PAL2 = 2 << 2
ATTR_PAL3 = 3 << 2
ATTR_PRIO = 1 << 5
