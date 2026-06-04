; helpers.s - Shared helper subroutines for 6502 scenarios
; ========================================================
; Linked with each scenario to avoid code duplication.
;
; Exported symbols:
;   y_save     - ZP byte for Y save across C calls ($F0)
;   str_ptr    - ZP word for print_str pointer
;   print_str  - print null-terminated string (A/X = ptr)
;   print_nl   - print newline
;   print_hex8 - print A as 2-digit hex
;   print_nibble - print low nibble of A as hex digit
;   print_dec  - print A as decimal (0-99)

.import _putchar
.export str_ptr
.export print_str, print_nl, print_hex8, print_nibble, print_dec

; High ZP save location (safe from C runtime which uses $02-$1B)
y_save = $F0

.segment "ZEROPAGE"
str_ptr: .res 2

.segment "CODE"

; print_str: print null-terminated string at (A/X = ptr)
; Preserves: Y (via y_save)
print_str:
    sta str_ptr
    stx str_ptr+1
    ldy #0
@ps_loop:
    lda (str_ptr),y
    beq @ps_done
    sty y_save
    jsr _putchar
    ldy y_save
    iny
    jmp @ps_loop
@ps_done:
    rts

; print_nl: print newline ($0A)
print_nl:
    pha
    lda #$0A
    jsr _putchar
    pla
    rts

; print_hex8: print A as 2-digit hex
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

; print_nibble: print low nibble of A as hex digit
print_nibble:
    cmp #10
    bcc @digit
    clc
    adc #'A' - '0' - 10
@digit:
    clc
    adc #'0'
    jmp _putchar

; print_dec: print A as decimal (0-99)
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
