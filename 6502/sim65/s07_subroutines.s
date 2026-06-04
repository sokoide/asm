; s07_subroutines.s — Subroutines and Parameter Passing
; Learning objectives:
;   - JSR / RTS — jump to subroutine / return
;   - Parameter passing via A/X/Y registers
;   - Register preservation with PHA / PLA
;   - Nested subroutine calls
;   - Return values in A register

.import print_str, print_nl, print_dec
.import _putchar
.export _main

.segment "RODATA"
msg_sum:  .asciiz "3 + 4 = "
msg_dbl:  .asciiz "Double of 5 = "
msg_nest: .asciiz "Nested: double(3+2) = "

.segment "BSS"
add_tmp: .res 1

.segment "CODE"
_main:
    ; ---- Demo 1: Basic subroutine ----
    lda #<msg_sum
    ldx #>msg_sum
    jsr print_str

    lda #3
    ldx #4
    jsr add_values
    jsr print_dec
    jsr print_nl

    ; ---- Demo 2: Return value ----
    lda #<msg_dbl
    ldx #>msg_dbl
    jsr print_str

    lda #5
    jsr double
    jsr print_dec
    jsr print_nl

    ; ---- Demo 3: Nested call ----
    lda #<msg_nest
    ldx #>msg_nest
    jsr print_str

    lda #3
    ldx #2
    jsr add_values
    jsr double
    jsr print_dec
    jsr print_nl

    lda #0
    rts

; ---- add A+X -> A ----
add_values:
    sta add_tmp
    txa
    clc
    adc add_tmp
    rts

; ---- double A ----
double:
    asl a
    rts
