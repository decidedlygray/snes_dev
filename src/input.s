; input.s - controller 1.
;
; With NMITIMEN bit 0 set, the CPU reads all controllers automatically at the
; start of every vblank and leaves the results in JOY1L-JOY4H.

.include "snes.inc"
.include "macros.inc"
.include "globals.inc"

.segment "ZEROPAGE"

pad_held:    .res 2     ; buttons currently down (JOY_* bits)
pad_pressed: .res 2     ; buttons that went down since the previous call

.segment "CODE"

; Update pad_held/pad_pressed. Call once per frame, after wait_frame.
; Preserves X and Y.
.proc read_joypad
    .a8
    .i16
@busy:
    lda HVBJOY          ; bit 0 is set while the automatic read is running
    and #$01
    bne @busy

    A16
    lda pad_held
    eor #$FFFF          ; buttons that were up last time...
    and JOY1L           ; ...and are down now
    sta pad_pressed
    lda JOY1L
    sta pad_held
    A8
    rts
.endproc
