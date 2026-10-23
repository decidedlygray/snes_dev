; init.s - power-on/reset: put the CPU and every PPU register in a known state.
;
; Nothing on the SNES is guaranteed at power-on: RAM, VRAM, palettes and most
; registers hold garbage. This follows the sequence recommended by the
; SNESdev wiki: https://snes.nesdev.org/wiki/Init_code

.include "snes.inc"
.include "macros.inc"
.include "globals.inc"

STACK_TOP = $1FFF       ; top of the first 8 KiB of WRAM; the stack grows down

.segment "CODE"

; The CPU starts here in 6502 emulation mode, executing from bank $00.
.proc reset_handler
    sei                 ; ignore IRQs while we set up
    clc
    xce                 ; carry -> emulation flag: switch to native 65816 mode

    rep #$38            ; 16-bit A and X/Y, decimal mode off
    .a16
    .i16
    ldx #STACK_TOP
    txs
    lda #$0000
    tcd                 ; direct page = $0000

    A8                  ; project convention from here on: A 8-bit, X/Y 16-bit
    phk
    plb                 ; data bank = program bank ($00): reaches registers + low RAM

    stz NMITIMEN        ; no NMI or auto-joypad yet
    stz HDMAEN
    lda #INIDISP_BLANK | $0F
    sta INIDISP         ; forced blank

    ; Clear all 128 KiB of work RAM with two 64 KiB DMA transfers that copy
    ; one zero byte over and over into WMDATA. This wipes the stack too, so it
    ; has to happen inline, before any jsr.
    stz WMADDL
    stz WMADDM
    stz WMADDH
    lda #DMAP_FIXED | DMAP_1REG
    sta DMAP0
    lda #<WMDATA
    sta BBAD0
    ldx #.loword(zero_byte)
    stx A1T0L
    lda #^zero_byte
    sta A1B0
    ldx #$0000          ; byte count 0 = 65536
    stx DAS0L
    lda #$01
    sta MDMAEN          ; first 64 KiB (the CPU pauses until the DMA is done)
    stx DAS0L
    sta MDMAEN          ; second 64 KiB: WMADD carried on from where it stopped

    jsr reset_registers

    ldx #$0000          ; all 64 KiB of VRAM
    ldy #$0000
    jsr clear_vram
    jsr clear_cgram
    jsr clear_oam

    jmp main
.endproc

; Write the documented power-on values to every PPU and CPU register.
; Leaves the screen in forced blank. Safe to call again between scenes.
.proc reset_registers
    .a8
    .i16
    lda #INIDISP_BLANK
    sta INIDISP

    stz OBJSEL
    stz OAMADDL
    stz OAMADDH
    stz BGMODE
    stz MOSAIC
    stz BG1SC
    stz BG2SC
    stz BG3SC
    stz BG4SC
    stz BG12NBA
    stz BG34NBA

    ; Scroll registers are write-twice. Vertical scroll is set to -1 because
    ; the PPU never displays scanline 0; with -1, tilemap row 0 is the top
    ; visible row and the 224-line screen shows rows 0-27.
    lda #$FF
    stz BG1HOFS
    stz BG1HOFS
    sta BG1VOFS
    sta BG1VOFS
    stz BG2HOFS
    stz BG2HOFS
    sta BG2VOFS
    sta BG2VOFS
    stz BG3HOFS
    stz BG3HOFS
    sta BG3VOFS
    sta BG3VOFS
    stz BG4HOFS
    stz BG4HOFS
    sta BG4VOFS
    sta BG4VOFS

    lda #$80
    sta VMAIN           ; VRAM address advances after writing the high byte

    stz M7SEL
    lda #$01            ; Mode 7 matrix = identity (1.0 is $0100)
    stz M7A
    sta M7A
    stz M7B
    stz M7B
    stz M7C
    stz M7C
    stz M7D
    sta M7D
    stz M7X
    stz M7X
    stz M7Y
    stz M7Y

    stz W12SEL
    stz W34SEL
    stz WOBJSEL
    stz WH0
    stz WH1
    stz WH2
    stz WH3
    stz WBGLOG
    stz WOBJLOG

    stz TM
    stz TS
    stz TMW
    stz TSW

    lda #$30
    sta CGWSEL          ; color math off
    stz CGADSUB
    lda #$E0
    sta COLDATA         ; fixed color = black
    stz SETINI

    lda #$FF
    sta WRIO
    stz MEMSEL          ; SlowROM (matches the header's map mode)
    rts
.endproc

.segment "RODATA"

zero_byte:  .byte $00   ; DMA fill source
