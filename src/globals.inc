; globals.inc - symbols shared between modules.
;
; ca65's .global exports a symbol from the module that defines it and imports
; it everywhere else, so every module can include this one file.

; init.s
.global reset_handler, zero_byte

; header.s
.global empty_handler

; video.s
.global nmi_handler, wait_frame, fade_in, fade_out
.global dma_to_vram, dma_to_cgram, clear_vram, clear_cgram, clear_oam
.global clear_tilemaps, draw_text_list
.globalzp frame_count, inidisp_shadow, tm_shadow

; input.s
.global read_joypad
.globalzp pad_held, pad_pressed

; main.s
.global main

; vram_copy src, dest, size - DMA `size` bytes from `src` to VRAM word
; address `dest`. Forced blank or vblank only.
.macro vram_copy src, dest, size
    ldx #dest
    stx VMADDL
    lda #^(src)
    ldx #.loword(src)
    ldy #size
    jsr dma_to_vram
.endmacro

; cgram_copy src, index, size - DMA `size` bytes of colors from `src` into
; CGRAM starting at color `index`. Forced blank or vblank only.
.macro cgram_copy src, index, size
    lda #index
    sta CGADD
    lda #^(src)
    ldx #.loword(src)
    ldy #size
    jsr dma_to_cgram
.endmacro
