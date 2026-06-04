; s04_loops.s — Loops and Conditional Branches
; Learning objectives:
;   - CMP / CPX / CPY — compare (updates flags only)
;   - BEQ / BNE — branch on zero / not-zero
;   - BCC / BCS — branch on carry clear / set
;   - BMI / BPL — branch on minus / plus
;   - Classic countdown loop: DEX + BNE

.import print_str, print_nl, print_hex8
.import _putchar
.export _main

.segment "ZEROPAGE"
tmp_x: .res 1

.segment "RODATA"
msg_count: .asciiz "Countdown: "
msg_even:  .asciiz "Even (0-8): "

.segment "CODE"
_main:
    ; ---- Demo 1: Countdown (DEX + BNE) ----
    lda #<msg_count
    ldx #>msg_count
    jsr print_str

    ldx #5
@loop1:
    stx tmp_x
    txa
    clc
    adc #'0'
    jsr _putchar
    lda #' '
    jsr _putchar
    ldx tmp_x
    dex
    bne @loop1
    jsr print_nl

    ; ---- Demo 2: Even numbers ----
    lda #<msg_even
    ldx #>msg_even
    jsr print_str

    ldx #0
@loop2:
    stx tmp_x
    txa
    and #$01
    bne @skip
    txa
    clc
    adc #'0'
    jsr _putchar
    lda #' '
    jsr _putchar
@skip:
    ldx tmp_x
    inx
    cpx #10
    bne @loop2
    jsr print_nl

    lda #0
    rts
