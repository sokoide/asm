; s08_zeropage.s - Scenario 8: Zero Page and Indirect Addressing
; =========================================
; Learning objectives:
;   - Zero page $00-$FF — shorter instructions, faster access
;   - Using zero page for frequently accessed variables
;   - (Indirect,X) — pointer table access
;   - (Indirect),Y — struct/string access via pointer

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
ptr:     .res 2
counter: .res 1
y_save:  .res 1

; ---- Read-only data ----
.segment "RODATA"
msg_hdr:  .asciiz "--- Zero Page Demo ---"
msg_zp:   .asciiz "ZP counter: "
msg_ptr:  .asciiz "String via (ZP),Y: "

hello_str: .asciiz "Hello via pointer!"

; ---- Code ----
.segment "CODE"
_main:
    ; ---- Demo 1: Zero page counter ----
    jsr print_msg_hdr
    jsr print_nl

    lda #5
    sta counter
    jsr print_msg_zp
@loop1:
    lda counter
    jsr print_dec_a
    lda #' '
    jsr _putchar
    dec counter
    lda counter
    cmp #$FF
    bne @loop1
    jsr print_nl

    ; ---- Demo 2: String via (Indirect),Y ----
    jsr print_msg_ptr
    lda #<hello_str
    sta ptr
    lda #>hello_str
    sta ptr+1
    ldy #0
@loop2:
    lda (ptr),y
    beq @done2
    sty y_save
    jsr _putchar
    ldy y_save
    iny
    jmp @loop2
@done2:
    jsr print_nl

    lda #0
    rts

; ---- Individual string print functions ----
print_msg_hdr:
    lda #'-'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #' '
    jsr _putchar
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
    lda #'D'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'m'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'-'
    jsr _putchar
    rts

print_msg_zp:
    lda #'Z'
    jsr _putchar
    lda #'P'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'c'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    rts

print_msg_ptr:
    lda #'S'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #'g'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'v'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'('
    jsr _putchar
    lda #'Z'
    jsr _putchar
    lda #'P'
    jsr _putchar
    lda #')'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'Y'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    rts

; ---- Shared helper subroutines ----

; ---- print newline ----
print_nl:
    lda #$0A
    jsr _putchar
    rts

; ---- print A as decimal (0-99) ----
print_dec_a:
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
