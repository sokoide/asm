; s07_subroutines.s - Scenario 7: Subroutines
; =========================================
; Learning objectives:
;   - JSR / RTS — jump to subroutine / return
;   - Parameter passing via A/X/Y registers
;   - Register preservation with PHA / PLA
;   - Nested subroutine calls
;   - Return values in A register

; High ZP save location (safe from C runtime which uses $02-$1B)
y_save = $F0

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
str_ptr: .res 2

; ---- Read-only data ----
.segment "RODATA"
msg_sum:  .asciiz "3 + 4 = "
msg_dbl:  .asciiz "Double of 5 = "
msg_nest: .asciiz "Nested: double(3+2) = "
nl:       .asciiz ""

; ---- Code ----
.segment "CODE"
_main:
    ; ---- Demo 1: Basic subroutine ----
    lda #<msg_sum
    ldx #>msg_sum
    jsr print_str

    lda #3
    ldx #4
    jsr add_values   ; A = 7
    jsr print_dec
    lda #$0A
    jsr _putchar

    ; ---- Demo 2: Return value ----
    lda #<msg_dbl
    ldx #>msg_dbl
    jsr print_str

    lda #5
    jsr double       ; A = 10
    jsr print_dec
    lda #$0A
    jsr _putchar

    ; ---- Demo 3: Nested call ----
    lda #<msg_nest
    ldx #>msg_nest
    jsr print_str

    lda #3
    ldx #2
    jsr add_values   ; A = 5
    jsr double       ; A = 10
    jsr print_dec
    lda #$0A
    jsr _putchar

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

; ---- print A as decimal (0-99) ----
print_dec:
    pha
    ldx #0
@tens:
    cmp #10
    bcc @ones
    sbc #10
    inx
    jmp @tens
@ones:
    pha
    cpx #0
    beq @skip_tens
    txa
    clc
    adc #'0'
    jsr _putchar
@skip_tens:
    pla
    clc
    adc #'0'
    jsr _putchar
    pla
    rts

; ---- print null-terminated string (A/X = ptr, no newline) ----
print_str:
    sta str_ptr
    stx str_ptr+1
    ldy #0
@ps_loop:
    lda (str_ptr),y
    beq @ps_done
    sty y_save          ; save Y before C call (putchar destroys Y)
    jsr _putchar
    ldy y_save          ; restore Y
    iny
    jmp @ps_loop
@ps_done:
    rts

.segment "BSS"
add_tmp: .res 1
