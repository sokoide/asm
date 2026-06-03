; s02_registers.s - Scenario 2: Registers and Data Transfer
; =========================================
; Learning objectives:
;   - A / X / Y registers (6502's three general-purpose registers)
;   - LDA / LDX / LDY — load immediate values
;   - STA / STX / STY — store register to memory
;   - TAX / TXA / TAY / TYA — register-to-register transfer
;   - Observing values via direct string output + print_hex8 helper

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
tmp_val: .res 3

; ---- Read-only data ----
.segment "RODATA"
msg_a:      .asciiz "A=$"
msg_x:      .asciiz " X=$"
msg_y:      .asciiz " Y=$"
msg_xfer:   .asciiz "After TAX+INX+TXA: A=$"
msg_x2:     .asciiz " X=$"
nl:         .byte $0A, $00

; ---- Code ----
.segment "CODE"
_main:
    ; ---- Demo 1: Load immediate values ----
    lda #$42
    ldx #$07
    ldy #$FF

    ; Save A, X, Y before any C function calls
    sta tmp_val
    stx tmp_val+1
    sty tmp_val+2

    ; Print "A=$42"
    jsr print_msg_a
    lda tmp_val
    jsr print_hex8

    ; Print " X=$07"
    jsr print_msg_x
    lda tmp_val+1
    jsr print_hex8

    ; Print " Y=$FF"
    jsr print_msg_y
    lda tmp_val+2
    jsr print_hex8

    jsr print_nl

    ; ---- Demo 2: Register transfers ----
    lda #$10        ; A = $10
    tax             ; X = A = $10
    inx             ; X = $11
    txa             ; A = X = $11

    ; Save results before any C function calls
    sta tmp_val
    stx tmp_val+1

    ; Print "After TAX+INX+TXA: A=$11"
    jsr print_msg_xfer
    lda tmp_val
    jsr print_hex8

    ; Print " X=$11"
    jsr print_msg_x2
    lda tmp_val+1
    jsr print_hex8

    jsr print_nl

    lda #0
    rts

; ---- Individual string print functions ----
print_msg_a:
    lda #'A'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_x:
    lda #' '
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_y:
    lda #' '
    jsr _putchar
    lda #'Y'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_xfer:
    lda #'A'
    jsr _putchar
    lda #'f'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'T'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'I'
    jsr _putchar
    lda #'N'
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'T'
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_x2:
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
