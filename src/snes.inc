; snes.inc - S-PPU / S-CPU hardware register addresses and bit constants.
;
; Names follow the SNESdev wiki: https://snes.nesdev.org/wiki/SNESdev_Wiki
; All of these live in banks $00-$3F and $80-$BF, so with the data bank
; register (DBR) set to $00 they are reachable with absolute addressing.

; ---------------------------------------------------------------------------
; PPU registers ($2100-$213F)
; ---------------------------------------------------------------------------
INIDISP  = $2100    ; display control: bit 7 forced blank, bits 0-3 brightness
OBJSEL   = $2101    ; sprite size and tile base
OAMADDL  = $2102    ; OAM address
OAMADDH  = $2103
OAMDATA  = $2104    ; OAM data write
BGMODE   = $2105    ; background mode and tile size
MOSAIC   = $2106
BG1SC    = $2107    ; BG1 tilemap address and size
BG2SC    = $2108
BG3SC    = $2109
BG4SC    = $210A
BG12NBA  = $210B    ; BG1/BG2 tile data base
BG34NBA  = $210C    ; BG3/BG4 tile data base
BG1HOFS  = $210D    ; scroll registers: write-twice (low byte, then high)
BG1VOFS  = $210E
BG2HOFS  = $210F
BG2VOFS  = $2110
BG3HOFS  = $2111
BG3VOFS  = $2112
BG4HOFS  = $2113
BG4VOFS  = $2114
VMAIN    = $2115    ; VRAM address increment mode
VMADDL   = $2116    ; VRAM word address
VMADDH   = $2117
VMDATAL  = $2118    ; VRAM data write (low byte, then high byte)
VMDATAH  = $2119
M7SEL    = $211A    ; Mode 7 settings and matrix
M7A      = $211B
M7B      = $211C
M7C      = $211D
M7D      = $211E
M7X      = $211F
M7Y      = $2120
CGADD    = $2121    ; palette (CGRAM) address
CGDATA   = $2122    ; palette data write: write-twice, BGR555 little-endian
W12SEL   = $2123    ; window settings
W34SEL   = $2124
WOBJSEL  = $2125
WH0      = $2126
WH1      = $2127
WH2      = $2128
WH3      = $2129
WBGLOG   = $212A
WOBJLOG  = $212B
TM       = $212C    ; main screen layer enable
TS       = $212D    ; sub screen layer enable
TMW      = $212E    ; main screen window mask
TSW      = $212F    ; sub screen window mask
CGWSEL   = $2130    ; color math control
CGADSUB  = $2131
COLDATA  = $2132    ; fixed color
SETINI   = $2133    ; interlace / overscan / pseudo-hires
MPYL     = $2134    ; PPU multiply result
MPYM     = $2135
MPYH     = $2136
SLHV     = $2137    ; latch H/V counters
RDOAM    = $2138
RDVRAML  = $2139
RDVRAMH  = $213A
RDCGRAM  = $213B
OPHCT    = $213C
OPVCT    = $213D
STAT77   = $213E
STAT78   = $213F

; ---------------------------------------------------------------------------
; APU communication ports and WRAM access port
; ---------------------------------------------------------------------------
APUIO0   = $2140
APUIO1   = $2141
APUIO2   = $2142
APUIO3   = $2143

WMDATA   = $2180    ; WRAM data, auto-increments WMADD
WMADDL   = $2181    ; 17-bit WRAM address
WMADDM   = $2182
WMADDH   = $2183

; ---------------------------------------------------------------------------
; CPU registers ($4200-$421F)
; ---------------------------------------------------------------------------
NMITIMEN = $4200    ; interrupt enable: bit 7 NMI, bit 0 auto-joypad read
WRIO     = $4201
WRMPYA   = $4202    ; 8x8 multiply
WRMPYB   = $4203
WRDIVL   = $4204    ; 16/8 divide
WRDIVH   = $4205
WRDIVB   = $4206
HTIMEL   = $4207    ; H/V timer IRQ position
HTIMEH   = $4208
VTIMEL   = $4209
VTIMEH   = $420A
MDMAEN   = $420B    ; start general-purpose DMA (one bit per channel)
HDMAEN   = $420C    ; enable HDMA channels
MEMSEL   = $420D    ; bit 0: FastROM
RDNMI    = $4210    ; NMI flag (read to acknowledge) and CPU version
TIMEUP   = $4211    ; IRQ flag
HVBJOY   = $4212    ; bit 7 vblank, bit 6 hblank, bit 0 auto-joypad busy
RDIO     = $4213
RDDIVL   = $4214
RDDIVH   = $4215
RDMPYL   = $4216
RDMPYH   = $4217
JOY1L    = $4218    ; auto-joypad results, controller 1-4
JOY1H    = $4219
JOY2L    = $421A
JOY2H    = $421B
JOY3L    = $421C
JOY3H    = $421D
JOY4L    = $421E
JOY4H    = $421F

; ---------------------------------------------------------------------------
; DMA registers. Channel n is at $43n0-$43nA; channel 0 is spelled out.
; ---------------------------------------------------------------------------
DMAP0    = $4300    ; transfer parameters
BBAD0    = $4301    ; B-bus target: low byte of a $21xx register
A1T0L    = $4302    ; A-bus source address (16-bit)
A1T0H    = $4303
A1B0     = $4304    ; A-bus source bank
DAS0L    = $4305    ; byte count (16-bit, 0 means 65536)
DAS0H    = $4306

DMAP_1REG    = $00  ; transfer pattern: one register
DMAP_2REG    = $01  ; transfer pattern: two registers, alternating (VMDATAL/H)
DMAP_FIXED   = $08  ; don't increment the source address

; ---------------------------------------------------------------------------
; Bit constants
; ---------------------------------------------------------------------------
INIDISP_BLANK = $80 ; forced blank: display off, VRAM/CGRAM/OAM freely writable

NMITIMEN_NMI      = $80
NMITIMEN_AUTOJOY  = $01

TM_BG1 = $01
TM_BG2 = $02
TM_BG3 = $04
TM_BG4 = $08
TM_OBJ = $10

; Controller buttons as a 16-bit read of JOY1L/JOY1H.
JOY_B      = $8000
JOY_Y      = $4000
JOY_SELECT = $2000
JOY_START  = $1000
JOY_UP     = $0800
JOY_DOWN   = $0400
JOY_LEFT   = $0200
JOY_RIGHT  = $0100
JOY_A      = $0080
JOY_X      = $0040
JOY_L      = $0020
JOY_R      = $0010
