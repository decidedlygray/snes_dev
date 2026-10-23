; macros.inc - register-width switches and small data helpers.
;
; The 65816 accumulator and index registers can each be 8 or 16 bits wide,
; selected by the M and X flags. The assembler has to know the current width
; to emit the right size of immediate operand (`lda #$12` vs `lda #$1234`),
; but it can't track the flags itself. Each macro below flips the CPU flag
; and tells ca65 about it, so the two never drift apart.
;
; Project convention: A is 8-bit and X/Y are 16-bit (.a8 / .i16) between
; routines. A routine that changes widths restores them before returning.

.macro A8
    sep #$20
    .a8
.endmacro

.macro A16
    rep #$20
    .a16
.endmacro

.macro I8
    sep #$10
    .i8
.endmacro

.macro I16
    rep #$10
    .i16
.endmacro

.macro AXY8
    sep #$30
    .a8
    .i8
.endmacro

.macro AXY16
    rep #$30
    .a16
    .i16
.endmacro

; rgb r, g, b - one CGRAM color from 8-bit-per-channel values (like a hex
; color in an image editor). The SNES stores colors as 15-bit BGR555:
; %0bbbbbgg gggrrrrr. The low 3 bits of each channel are dropped.
.macro rgb r, g, b
    .word (((b) >> 3) << 10) | (((g) >> 3) << 5) | ((r) >> 3)
.endmacro

; text_at map, col, row, attr, "string" - one entry of a text list for
; draw_text_list: the tilemap word address, the tile attribute byte
; (palette/priority, see ATTR_* in vram.inc) and a zero-terminated string.
; End a list with `.word TEXT_END`.
.macro text_at map, col, row, attr, str
    .word (map) + (row) * 32 + (col)
    .byte attr
    .byte str, 0
.endmacro

; text_center map, row, attr, "string" - same, horizontally centred.
.macro text_center map, row, attr, str
    text_at map, (32 - .strlen(str)) / 2, row, attr, str
.endmacro

TEXT_END = $FFFF
