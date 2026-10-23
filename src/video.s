; video.s - vblank handling, fades, DMA helpers and text drawing.
;
; The PPU only accepts VRAM/CGRAM/OAM writes while it isn't drawing: during
; vertical blank (~37 scanlines per frame) or while the screen is in forced
; blank. This program keeps it simple: every bulk load happens in forced blank
; between scenes, and the NMI handler only copies a couple of "shadow"
; registers that the main code sets whenever it likes.

.include "snes.inc"
.include "macros.inc"
.include "globals.inc"
.include "vram.inc"

.segment "ZEROPAGE"

frame_count:    .res 2  ; incremented once per frame by the NMI handler
inidisp_shadow: .res 1  ; copied to INIDISP every vblank
tm_shadow:      .res 1  ; copied to TM (enabled layers) every vblank
text_attr:      .res 1  ; scratch for draw_text_list

.segment "CODE"

; Runs at the start of every vertical blank once NMI is enabled in NMITIMEN.
.proc nmi_handler
    AXY16               ; save the full 16-bit registers, whatever their width
    pha
    phx
    phy
    phb
    phk
    plb                 ; DBR = $00 so register addresses resolve

    A8
    lda RDNMI           ; reading RDNMI acknowledges the NMI
    lda inidisp_shadow
    sta INIDISP
    lda tm_shadow
    sta TM

    A16
    inc frame_count     ; (X/Y are still 16-bit from the AXY16 above)

    plb
    ply
    plx
    pla
    rti                 ; also restores P, and with it the interrupted code's
                        ; register widths
.endproc

; Sleep until the next NMI has run. Preserves A, X and Y.
.proc wait_frame
    .a8
    .i16
    pha
    lda frame_count
@wait:
    wai                 ; halt until an interrupt
    cmp frame_count
    beq @wait
    pla
    rts
.endproc

; Turn the display on and ramp brightness from 0 to 15 over 32 frames.
.proc fade_in
    .a8
    .i16
    lda #$00
@step:
    sta inidisp_shadow
    jsr wait_frame
    jsr wait_frame
    inc a
    cmp #$10
    bne @step
    rts
.endproc

; Ramp brightness down to 0, then enter forced blank. Returns during vblank
; with the display off, so VRAM is safe to write.
.proc fade_out
    .a8
    .i16
    lda #$0F
@step:
    sta inidisp_shadow
    jsr wait_frame
    jsr wait_frame
    dec a
    bpl @step
    lda #INIDISP_BLANK
    sta inidisp_shadow
    jsr wait_frame
    rts
.endproc

; DMA a block into VRAM with channel 0.
; In: A = source bank, X = source address, Y = byte count;
;     VMADD = destination word address (VMAIN = $80).
.proc dma_to_vram
    .a8
    .i16
    stx A1T0L
    sta A1B0
    sty DAS0L
    lda #DMAP_2REG      ; alternate VMDATAL / VMDATAH, source increments
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    lda #$01
    sta MDMAEN
    rts
.endproc

; DMA a block of colors into CGRAM with channel 0.
; In: A = source bank, X = source address, Y = byte count; CGADD = first color.
.proc dma_to_cgram
    .a8
    .i16
    stx A1T0L
    sta A1B0
    sty DAS0L
    lda #DMAP_1REG
    sta DMAP0
    lda #<CGDATA
    sta BBAD0
    lda #$01
    sta MDMAEN
    rts
.endproc

; Zero a range of VRAM. In: X = word address, Y = byte count (0 = 64 KiB).
.proc clear_vram
    .a8
    .i16
    stx VMADDL
    lda #DMAP_FIXED | DMAP_2REG
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    ldx #.loword(zero_byte)
    stx A1T0L
    lda #^zero_byte
    sta A1B0
    sty DAS0L
    lda #$01
    sta MDMAEN
    rts
.endproc

; Set all 256 colors to black.
.proc clear_cgram
    .a8
    .i16
    stz CGADD
    lda #DMAP_FIXED | DMAP_1REG
    sta DMAP0
    lda #<CGDATA
    sta BBAD0
    ldx #.loword(zero_byte)
    stx A1T0L
    lda #^zero_byte
    sta A1B0
    ldx #512
    stx DAS0L
    lda #$01
    sta MDMAEN
    rts
.endproc

; Move all 128 sprites below the visible area (Y = 240). Sprites aren't
; used yet, but this means turning the sprite layer on later shows nothing
; unexpected.
.proc clear_oam
    .a8
    .i16
    stz OAMADDL
    stz OAMADDH
    lda #240
    ldx #128
@sprite:
    stz OAMDATA         ; X
    sta OAMDATA         ; Y
    stz OAMDATA         ; tile
    stz OAMDATA         ; attributes
    dex
    bne @sprite
    ldx #32             ; high table: X bit 8 and size bit, 2 bits per sprite
@high:
    stz OAMDATA
    dex
    bne @high
    rts
.endproc

; Clear the BG1 and BG2 tilemaps (they're adjacent in VRAM).
.proc clear_tilemaps
    .a8
    .i16
    ldx #BG1_MAP
    ldy #2 * 2 * 32 * 32    ; two maps of 32x32 two-byte entries
    jmp clear_vram
.endproc

; Write a list of strings into tilemaps (forced blank only).
; In: X = address of a text list in bank $00, built with text_at /
;     text_center and ended with `.word TEXT_END`. The font is loaded so that
;     tile number == ASCII code, so each character is written as-is.
.proc draw_text_list
    .a8
    .i16
@string:
    A16
    lda a:$0000,x       ; tilemap word address
    cmp #TEXT_END
    beq @done
    sta VMADDL
    A8
    lda a:$0002,x       ; attribute byte for every character in the string
    sta text_attr
    inx
    inx
    inx
@char:
    lda a:$0000,x
    beq @next
    sta VMDATAL         ; tile number = character code
    lda text_attr
    sta VMDATAH         ; palette/priority; this write advances VMADD
    inx
    bra @char
@next:
    inx                 ; skip the terminator
    bra @string
@done:
    A8
    rts
.endproc

