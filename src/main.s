; main.s - the game: studio logo -> title screen -> "well, hello world!"

.include "snes.inc"
.include "macros.inc"
.include "globals.inc"
.include "vram.inc"

LOGO_HOLD_FRAMES = 120          ; ~2 s at 60 Hz (Start skips ahead)
BLINK_BIT        = %00100000    ; PRESS START toggles every 32 frames

.segment "CODE"

; Entered from reset_handler: forced blank, RAM/VRAM/CGRAM cleared.
.proc main
    .a8
    .i16
    ; Mode 0: four 2bpp (4-color) background layers. We use BG1 and BG2.
    stz BGMODE
    lda #(BG1_MAP >> 8) & $FC
    sta BG1SC           ; 32x32 tilemap at BG1_MAP
    lda #(BG2_MAP >> 8) & $FC
    sta BG2SC
    lda #((BG_CHR >> 12) << 4) | (BG_CHR >> 12)
    sta BG12NBA         ; BG1 and BG2 share one set of tiles

    vram_copy font_chr, BG_CHR + FONT_TILE * 8, font_chr_end - font_chr
    vram_copy logo_chr, BG_CHR + LOGO_TILE * 8, logo_chr_end - logo_chr
    cgram_copy bg1_colors, 0, bg1_colors_end - bg1_colors
    cgram_copy bg2_colors, 32, bg2_colors_end - bg2_colors

    lda #INIDISP_BLANK
    sta inidisp_shadow  ; keep the display off until a scene fades in
    lda #NMITIMEN_NMI | NMITIMEN_AUTOJOY
    sta NMITIMEN

    jsr logo_scene
    jsr title_scene
    jmp hello_scene
.endproc

; "snes.dev" studio logo: fade in, hold, fade out.
.proc logo_scene
    .a8
    .i16
    jsr clear_tilemaps
    vram_copy logo_tilemap, BG1_MAP, logo_tilemap_end - logo_tilemap
    lda #TM_BG1
    sta tm_shadow
    jsr fade_in

    ldx #LOGO_HOLD_FRAMES
@hold:
    jsr wait_frame
    jsr read_joypad
    lda pad_pressed + 1 ; high byte: B Y Select Start Up Down Left Right
    and #>JOY_START
    bne @done
    dex
    bne @hold
@done:
    jmp fade_out
.endproc

; Title screen with a blinking PRESS START. Returns when Start is pressed.
.proc title_scene
    .a8
    .i16
    jsr clear_tilemaps
    ldx #title_text
    jsr draw_text_list
    lda #TM_BG1 | TM_BG2
    sta tm_shadow
    jsr fade_in

@frame:
    jsr wait_frame
    ; PRESS START sits alone on BG2, so blinking it is just a matter of
    ; switching that layer on and off; no VRAM writes needed.
    lda frame_count
    and #BLINK_BIT
    beq @show
    lda #TM_BG1
    bra @set
@show:
    lda #TM_BG1 | TM_BG2
@set:
    sta tm_shadow

    jsr read_joypad
    lda pad_pressed + 1
    and #>JOY_START
    beq @frame
    jmp fade_out
.endproc

; The "game". Never returns.
.proc hello_scene
    .a8
    .i16
    jsr clear_tilemaps
    ldx #hello_text
    jsr draw_text_list
    lda #TM_BG1
    sta tm_shadow
    jsr fade_in
@idle:
    wai                 ; nothing to do; the NMI handler keeps running
    bra @idle
.endproc

.segment "RODATA"

title_text:
    text_center BG1_MAP,  9, ATTR_PAL2, "HELLO WORLD"
    text_center BG1_MAP, 11, ATTR_PAL3, "a snes.dev proof of concept"
    text_center BG2_MAP, 18, ATTR_PAL0, "PRESS START"
    text_center BG1_MAP, 25, ATTR_PAL3, "(c) 2026 snes.dev"
    .word TEXT_END

hello_text:
    text_center BG1_MAP, 13, ATTR_PAL1, "well, hello world!"
    .word TEXT_END

; In Mode 0 each background has its own eight 4-color palettes: BG1 uses
; CGRAM 0-31, BG2 uses 32-63. Color 0 of every palette is transparent, and
; CGRAM 0 doubles as the backdrop color behind all layers.
bg1_colors:
    rgb $0C, $0A, $1C   ;  0 backdrop: near-black indigo
    rgb $F4, $F0, $FF   ;  1 palette 0 (logo): highlight
    rgb $A0, $80, $F0   ;  2                   body
    rgb $40, $28, $80   ;  3                   shadow
    rgb $00, $00, $00   ;  4 palette 1 (body text)
    rgb $F8, $F8, $F8   ;  5
    rgb $00, $00, $00   ;  6
    rgb $00, $00, $00   ;  7
    rgb $00, $00, $00   ;  8 palette 2 (accent text)
    rgb $B8, $98, $FF   ;  9
    rgb $00, $00, $00   ; 10
    rgb $00, $00, $00   ; 11
    rgb $00, $00, $00   ; 12 palette 3 (dim text)
    rgb $78, $70, $98   ; 13
bg1_colors_end:

bg2_colors:
    rgb $00, $00, $00   ; 32 palette 0 (PRESS START)
    rgb $F8, $D8, $50   ; 33
bg2_colors_end:

; Generated from assets/*.txt by tools/txt2chr.py (see Makefile).
font_chr:       .incbin "font.chr"
font_chr_end:
logo_chr:       .incbin "logo.chr"
logo_chr_end:
logo_tilemap:   .incbin "logo.tilemap"
logo_tilemap_end:
