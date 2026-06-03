; s06_addressing.s - Scenario 6: Addressing Modes
; =========================================
; Learning objectives:
;   - Immediate:       LDA #$42
;   - Zero Page:       LDA $20
;   - Absolute:        LDA addr
;   - Zero Page,X:     LDA $20,X
;   - Absolute,X:      LDA addr,X
;   - Absolute,Y:      LDA addr,Y
;   - (Indirect,X):    LDA ($20,X)
;   - (Indirect),Y:    LDA ($20),Y
;   - Implied:         TAX
;   - Accumulator:     ASL A
;   - Relative:        BEQ label
; ----
; Addressing modes are the most important concept on 6502!

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
zp_val:   .res 1
zp_ptr:   .res 2
zp_buf:   .res 4
tmp_val:  .res 1

; ---- Read-only data ----
.segment "RODATA"
abs_data: .byte $DE, $AD, $BE, $EF

; ---- Code ----
.segment "CODE"
_main:
    ; ---- 1. Immediate ----
    jsr print_msg_imm
    lda #$42
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 2. Zero Page ----
    lda #$77
    sta zp_val
    jsr print_msg_zp
    lda zp_val
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 3. Absolute ----
    jsr print_msg_abs
    lda abs_data
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 4. Zero Page,X ----
    lda #$11
    sta zp_buf
    lda #$22
    sta zp_buf+1
    lda #$33
    sta zp_buf+2
    jsr print_msg_zpx
    ldx #2
    lda zp_buf,x
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 5. Absolute,X ----
    jsr print_msg_abx
    ldx #1
    lda abs_data,x
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 6. Absolute,Y ----
    jsr print_msg_aby
    ldy #2
    lda abs_data,y
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 7. (Indirect,X) ----
    lda #<abs_data
    sta zp_ptr
    lda #>abs_data
    sta zp_ptr+1
    jsr print_msg_izx
    ldx #0
    lda (zp_ptr,x)
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 8. (Indirect),Y ----
    lda #<abs_data
    sta zp_ptr
    lda #>abs_data
    sta zp_ptr+1
    jsr print_msg_izy
    ldy #3
    lda (zp_ptr),y
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 9. Implied ----
    jsr print_msg_impl
    lda #$55
    tax
    txa
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 10. Accumulator ----
    jsr print_msg_asl
    lda #$41
    asl a
    sta tmp_val
    jsr print_result_prefix
    lda tmp_val
    jsr print_hex8
    jsr print_nl

    ; ---- 11. Relative ----
    lda #$42
    cmp #$42
    bne @skip_rel
    jsr print_msg_rel
@skip_rel:

    lda #0
    rts

; ---- Individual string print functions ----
print_msg_imm:
    lda #'I'
    jsr _putchar
    lda #'m'
    jsr _putchar
    lda #'m'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'#'
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'4'
    jsr _putchar
    lda #'2'
    jsr _putchar
    rts

print_result_prefix:
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'>'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_zp:
    lda #'Z'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'P'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'g'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'z'
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'_'
    jsr _putchar
    lda #'v'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'l'
    jsr _putchar
    rts

print_msg_abs:
    lda #'A'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'s'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'s'
    jsr _putchar
    lda #'_'
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'a'
    jsr _putchar
    rts

print_msg_zpx:
    lda #'Z'
    jsr _putchar
    lda #'P'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'z'
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'_'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'f'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'2'
    jsr _putchar
    rts

print_msg_abx:
    lda #'A'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'s'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'1'
    jsr _putchar
    rts

print_msg_aby:
    lda #'A'
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'s'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'Y'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'2'
    jsr _putchar
    rts

print_msg_izx:
    lda #'('
    jsr _putchar
    lda #'I'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #')'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'('
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'X'
    jsr _putchar
    lda #')'
    jsr _putchar
    rts

print_msg_izy:
    lda #'('
    jsr _putchar
    lda #'I'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #')'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'Y'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #'D'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'('
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #')'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'Y'
    jsr _putchar
    lda #'+'
    jsr _putchar
    lda #'3'
    jsr _putchar
    rts

print_msg_impl:
    lda #'I'
    jsr _putchar
    lda #'m'
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'T'
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #'X'
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
    lda #'5'
    jsr _putchar
    lda #'5'
    jsr _putchar
    rts

print_msg_asl:
    lda #'A'
    jsr _putchar
    lda #'c'
    jsr _putchar
    lda #'c'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'m'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #'S'
    jsr _putchar
    lda #'L'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'A'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'4'
    jsr _putchar
    lda #'1'
    jsr _putchar
    rts

print_msg_rel:
    lda #'R'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'v'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'B'
    jsr _putchar
    lda #'E'
    jsr _putchar
    lda #'Q'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'k'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'>'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'y'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'s'
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
