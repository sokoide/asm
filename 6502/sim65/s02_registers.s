; s02_registers.s — Registers, Data Transfer & Arithmetic
; Learning objectives:
;   - A / X / Y registers
;   - LDA / LDX / LDY — load immediate values
;   - STA / STX / STY — store register to memory
;   - TAX / TXA / TAY / TYA — register-to-register transfer
;   - ADC / SBC — add/subtract with carry
;   - CLC / SEC — clear/set carry flag
;   - INC / DEC — memory inc/dec
;   - INX / DEX / INY / DEY — register inc/dec
;   - Multi-byte (16-bit) addition using carry

.import print_str, print_nl, print_hex8, y_save
.export _main

.segment "ZEROPAGE"
tmp_val: .res 3

.segment "RODATA"
msg_a:     .asciiz "A=$"
msg_x:     .asciiz " X=$"
msg_y:     .asciiz " Y=$"
msg_xfer:  .asciiz "After TAX+INX+TXA: A=$"
msg_x2:    .asciiz " X=$"
msg_add8:  .asciiz "8-bit:  $30+$28=$"
msg_sub8:  .asciiz "8-bit:  $50-$20=$"
msg_add16: .asciiz "16-bit: $01FF+$0003=$"
msg_inx:   .asciiz "INX x2, DEX: X=$"

.segment "CODE"
_main:
    ; ---- Demo 1: Load immediate values ----
    lda #$42
    ldx #$07
    ldy #$FF

    sta tmp_val
    stx tmp_val+1
    sty tmp_val+2

    lda #<msg_a
    ldx #>msg_a
    jsr print_str
    lda tmp_val
    jsr print_hex8

    lda #<msg_x
    ldx #>msg_x
    jsr print_str
    lda tmp_val+1
    jsr print_hex8

    lda #<msg_y
    ldx #>msg_y
    jsr print_str
    lda tmp_val+2
    jsr print_hex8

    jsr print_nl

    ; ---- Demo 2: Register transfers ----
    lda #$10
    tax
    inx
    txa

    sta tmp_val
    stx tmp_val+1

    lda #<msg_xfer
    ldx #>msg_xfer
    jsr print_str
    lda tmp_val
    jsr print_hex8

    lda #<msg_x2
    ldx #>msg_x2
    jsr print_str
    lda tmp_val+1
    jsr print_hex8

    jsr print_nl

    ; ---- Demo 3: 8-bit arithmetic ----
    clc
    lda #$30
    adc #$28
    pha

    lda #<msg_add8
    ldx #>msg_add8
    jsr print_str
    pla
    jsr print_hex8
    jsr print_nl

    sec
    lda #$50
    sbc #$20
    pha

    lda #<msg_sub8
    ldx #>msg_sub8
    jsr print_str
    pla
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 4: 16-bit addition ----
    clc
    lda #$FF
    adc #$03
    sta tmp_val
    lda #$01
    adc #$00
    sta tmp_val+1

    lda #<msg_add16
    ldx #>msg_add16
    jsr print_str
    lda tmp_val+1
    jsr print_hex8
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 5: INX / DEX ----
    ldx #$08
    inx
    inx
    dex

    stx tmp_val

    lda #<msg_inx
    ldx #>msg_inx
    jsr print_str
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    lda #0
    rts
