; s03_arithmetic.s - Scenario 3: Arithmetic and Carry Flag
; =========================================
; Learning objectives:
;   - ADC / SBC — add/subtract with carry
;   - CLC / SEC — clear/set carry flag
;   - INC / DEC — memory increment/decrement
;   - INX / DEX / INY / DEY — register increment/decrement
;   - Multi-byte (16-bit) addition using carry

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
tmp_val: .res 2

; ---- Read-only data ----
.segment "RODATA"
msg_add8:   .asciiz "8-bit:  $30+$28=$"
msg_sub8:   .asciiz "8-bit:  $50-$20=$"
msg_add16:  .asciiz "16-bit: $01FF+$0003=$"
msg_inx:    .asciiz "INX x2, DEX: X=$"

; ---- Code ----
.segment "CODE"
_main:
    ; ---- Demo 1: 8-bit addition ($30+$28=$58) ----
    clc
    lda #$30
    adc #$28        ; A = $58
    pha             ; Save result

    jsr print_msg_add8
    pla
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 2: 8-bit subtraction ($50-$20=$30) ----
    sec
    lda #$50
    sbc #$20        ; A = $30
    pha             ; Save result

    jsr print_msg_sub8
    pla
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 3: 16-bit addition ($01FF + $0003 = $0202) ----
    clc
    lda #$FF
    adc #$03        ; low: $02, carry=1
    sta tmp_val
    lda #$01
    adc #$00        ; high: $01 + 0 + carry = $02
    sta tmp_val+1

    jsr print_msg_add16

    ; Print high byte
    lda tmp_val+1
    jsr print_hex8
    ; Print low byte
    lda tmp_val
    jsr print_hex8

    jsr print_nl

    ; ---- Demo 4: INX / DEX ----
    ldx #$08
    inx             ; X = $09
    inx             ; X = $0A
    dex             ; X = $09

    stx tmp_val     ; Save X before C function call

    jsr print_msg_inx
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    lda #0
    rts

; ---- Individual string print functions ----
print_msg_add8:
    lda #'8'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'3'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #'8'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_sub8:
    lda #'8'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'5'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_add16:
    lda #'1'
    jsr _putchar
    lda #'6'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'1'
    jsr _putchar
    lda #'F'
    jsr _putchar
    lda #'F'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'3'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_inx:
    lda #'I'
    jsr _putchar
    lda #'N'
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'x'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'E'
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

; ---- Shared helper subroutines ----

; ---- print newline ----
print_nl:
    lda #$0A
    jsr _putchar
    rts

; ---- print A as 2-digit hex ----
print_hex8:
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    jsr print_nibble
    pla
    and #$0F
    jsr print_nibble
    rts

print_nibble:
    cmp #10
    bcc @digit
    clc
    adc #'A' - '0' - 10
@digit:
    clc
    adc #'0'
@done:
    jsr _putchar
    rts
