; header.s - cartridge header and interrupt vectors.
;
; The SNES (and emulators, flash carts and copiers) read the "internal
; header" at the top of bank $00 to learn the ROM's name, memory map and
; size. In a LoROM image it is at file offset $7FB0-$7FDF, followed by the
; CPU's interrupt vectors at $7FE0-$7FFF.
;
; Reference: https://snes.nesdev.org/wiki/ROM_header
;            https://snes.nesdev.org/wiki/CPU_vectors

.include "snes.inc"
.include "globals.inc"

.define TITLE "HELLO WORLD"     ; up to 21 ASCII characters

.segment "HEADER"       ; $00:FFB0
    ; $FFB0-$FFBF: expanded header (maker/game code etc.). Only used when
    ; the developer ID below is $33; we don't need it, so it stays zero.
    .res 16, $00

    ; $FFC0: title, space-padded to 21 bytes
    .byte TITLE
    .res 21 - .strlen(TITLE), ' '

    .byte $20           ; $FFD5 map mode: %001smmmm, s=0 SlowROM, m=0 LoROM
    .byte $00           ; $FFD6 cartridge type: ROM only
    .byte $05           ; $FFD7 ROM size: 1 << 5 = 32 KiB
    .byte $00           ; $FFD8 RAM size: none
    .byte $01           ; $FFD9 destination: North America (NTSC)
    .byte $00           ; $FFDA developer ID ($33 would enable the expanded header)
    .byte $00           ; $FFDB version: 1.0
    .word $FFFF         ; $FFDC checksum complement \ patched after linking
    .word $0000         ; $FFDE checksum            / by tools/fix_checksum.py

.segment "VECTORS"      ; $00:FFE0
    ; Native mode (the CPU runs in native mode after reset_handler).
    ; Vectors are 16-bit: every handler must live in bank $00.
    .word $0000, $0000  ; $FFE0 unused
    .word empty_handler ; $FFE4 COP
    .word empty_handler ; $FFE6 BRK
    .word empty_handler ; $FFE8 ABORT (unused on the SNES)
    .word nmi_handler   ; $FFEA NMI: start of vertical blank
    .word $0000         ; $FFEC unused
    .word empty_handler ; $FFEE IRQ

    ; Emulation mode (6502-compatible). The CPU always powers on here.
    .word $0000, $0000  ; $FFF0 unused
    .word empty_handler ; $FFF4 COP
    .word $0000         ; $FFF6 unused
    .word empty_handler ; $FFF8 ABORT
    .word empty_handler ; $FFFA NMI
    .word reset_handler ; $FFFC RESET
    .word empty_handler ; $FFFE IRQ/BRK

.segment "CODE"

; Interrupts we never enable land here and return immediately.
.proc empty_handler
    rti
.endproc
