; s101_zeropage.s - Scenario 101: Zero Page Fast Access (arch-specific)
; ======================================================================
; The 6502's zero page ($0000-$00FF) is its "register file": zp-addressed
; instructions are 1 byte shorter and 1 cycle faster than their absolute
; counterparts. This scenario runs the same 10-iteration add loop with
; zp and absolute addressing and prints both results.
;
; Cycle breakdown of the inner loop (6502 datasheet, sim65 -c exact):
;
;   zp version            abs version
;   LDA zp     3          LDA abs    4
;   CLC        2          CLC        2
;   ADC #1     2          ADC #1     2
;   STA zp     3          STA abs    4
;   DEY        2          DEY        2
;   BNE        3/2        BNE        3/2     (3 taken, 2 not taken)
;   ---------------       ---------------
;   15 cycles/iter        17 cycles/iter   -> +2 cycles per iteration
;
;   LDY #10 = 2, 10 iterations:
;   zp : 2 + 15 x 9 + 14 = 151 cycles
;   abs: 2 + 17 x 9 + 16 = 171 cycles  (20 cycles slower over 10 iters)
;
; Also demonstrates (zp),Y indirect indexed access through a zero page
; pointer: LDA (zp),Y = 5 cycles (+1 when Y crosses a page boundary).
; This is the 6502's main pointer mechanism - there is no 16-bit
; indirect register like HL on the Z80.

.import print_str, print_nl, print_hex8, print_dec, _putchar
.export _main

.segment "ZEROPAGE"
zp_val:     .res 1
zp_ptr:     .res 2
y_tmp:      .res 1    ; Y save across _putchar (clobbers X/Y)

.segment "RODATA"
msg_hdr:    .asciiz "--- Zero Page Fast Access ---"
msg_zp:     .asciiz "zp  loop result = "
msg_abs:    .asciiz "abs loop result = "
msg_ptr:    .asciiz "(zp),Y bytes    = "
table:      .byte $DE, $AD, $BE, $EF

.segment "BSS"
abs_val:    .res 1

.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    jsr print_nl

; ---- Demo 1: zp-addressed loop (15 cycles/iter) ----
    lda #0
    sta zp_val
    ldy #10            ; 2
@zp_loop:
    lda zp_val         ; 3
    clc                ; 2
    adc #1             ; 2
    sta zp_val         ; 3
    dey                ; 2
    bne @zp_loop       ; 3 taken / 2 last
; total: 2 + 15 x 9 + 14 = 151 cycles

    lda #<msg_zp
    ldx #>msg_zp
    jsr print_str
    lda zp_val
    jsr print_dec
    jsr print_nl

; ---- Demo 2: absolute-addressed loop (17 cycles/iter) ----
    lda #0
    sta abs_val
    ldy #10            ; 2
@abs_loop:
    lda abs_val        ; 4
    clc                ; 2
    adc #1             ; 2
    sta abs_val        ; 4
    dey                ; 2
    bne @abs_loop      ; 3 taken / 2 last
; total: 2 + 17 x 9 + 16 = 171 cycles

    lda #<msg_abs
    ldx #>msg_abs
    jsr print_str
    lda abs_val
    jsr print_dec
    jsr print_nl

; ---- Demo 3: (zp),Y pointer walk over a table ----
    lda #<table
    sta zp_ptr
    lda #>table
    sta zp_ptr+1
    ldy #0
@walk:
    lda (zp_ptr),y     ; 5 cycles (+1 on page cross)
    sty y_tmp          ; _putchar clobbers X/Y - save Y
    jsr print_hex8
    lda #' '
    jsr _putchar
    ldy y_tmp
    iny
    cpy #4
    bne @walk
    jsr print_nl

    lda #0
    rts
