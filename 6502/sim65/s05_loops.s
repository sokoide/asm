; s05_loops.s - Scenario 5: Loops and Conditional Branches
; =========================================
; Learning objectives:
;   - CMP / CPX / CPY — compare (updates flags only)
;   - BEQ / BNE — branch on zero / not-zero
;   - BCC / BCS — branch on carry clear / set
;   - BMI / BPL — branch on minus / plus
;   - Classic countdown loop: DEX + BNE

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
tmp_x: .res 1

; ---- Read-only data ----
.segment "RODATA"
msg_count: .asciiz "Countdown: "
msg_even:  .asciiz "Even (0-8): "
msg_beq:   .asciiz "CMP $42,$42 -> BEQ taken (equal)"
msg_bcc:   .asciiz "CMP $10,$20 -> BCC taken (borrow)"

; ---- Code ----
.segment "CODE"
_main:
    ; ---- Demo 1: Countdown (DEX + BNE) ----
    jsr print_msg_count

    ldx #5
@loop1:
    stx tmp_x       ; Save X before _putchar call
    txa
    clc
    adc #'0'
    jsr _putchar
    lda #' '
    jsr _putchar
    ldx tmp_x       ; Restore X
    dex
    bne @loop1
    lda #$0A
    jsr _putchar

    ; ---- Demo 2: Even numbers with loop ----
    jsr print_msg_even

    ldx #0
@loop2:
    stx tmp_x       ; Save X
    txa
    and #$01        ; bit 0 = 0 -> even
    bne @skip
    txa
    clc
    adc #'0'
    jsr _putchar
    lda #' '
    jsr _putchar
@skip:
    ldx tmp_x       ; Restore X
    inx
    cpx #10
    bne @loop2
    lda #$0A
    jsr _putchar

    ; ---- Demo 3: CMP + BEQ ----
    lda #$42
    cmp #$42        ; Z=1
    bne @skip_beq
    jsr print_msg_beq
    lda #$0A
    jsr _putchar
@skip_beq:

    ; ---- Demo 4: CMP + BCC ----
    lda #$10
    cmp #$20        ; C=0 (borrow)
    bcs @skip_bcc
    jsr print_msg_bcc
    lda #$0A
    jsr _putchar
@skip_bcc:

    lda #0
    rts

; ---- Individual string print functions ----
print_msg_count:
    lda #'C'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'d'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'w'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    rts

print_msg_even:
    lda #'E'
    jsr _putchar
    lda #'v'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'n'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'('
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'8'
    jsr _putchar
    lda #')'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    rts

print_msg_beq:
    lda #'C'
    jsr _putchar
    lda #'M'
    jsr _putchar
    lda #'P'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'4'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'4'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'>'
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
    lda #'('
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'q'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #')'
    jsr _putchar
    rts

print_msg_bcc:
    lda #'C'
    jsr _putchar
    lda #'M'
    jsr _putchar
    lda #'P'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'1'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #','
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'>'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'B'
    jsr _putchar
    lda #'C'
    jsr _putchar
    lda #'C'
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
    lda #'('
    jsr _putchar
    lda #'b'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'w'
    jsr _putchar
    lda #')'
    jsr _putchar
    rts

; ---- Shared helper subroutines ----

; ---- print newline ----
print_nl:
    lda #$0A
    jsr _putchar
    rts
