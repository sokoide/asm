; s09_branching.s - Scenario 9: Conditional Branching
; ========================================
; Learning objectives:
;   - CMP: compare A (sets flags, does not modify)
;   - BEQ/BNE — branch equal / not equal
;   - BCC/BCS — branch carry clear / set
;   - BMI/BPL — branch minus / plus
;   - Decision trees with CMP + Bcc chains

.import print_str, print_nl
.import _putchar
.export _main

.segment "RODATA"
msg_beq:  .asciiz "CMP $42,$42 -> BEQ taken (equal)"
msg_bne:  .asciiz "CMP $42,$50 -> BNE taken (not equal)"
msg_bcc:  .asciiz "CMP $10,$20 -> BCC taken (borrow)"
msg_bcs:  .asciiz "CMP $20,$10 -> BCS taken (no borrow)"
msg_ife:  .asciiz "A=$50: "
msg_small:.asciiz "small (<$30)"
msg_mid:  .asciiz "mid ($30..$7F)"
msg_big:  .asciiz "big (>=$80)"

.segment "CODE"
_main:
    ; ---- Demo 1: BEQ ----
    lda #$42
    cmp #$42
    bne @skip_beq
    lda #<msg_beq
    ldx #>msg_beq
    jsr print_str
    jsr print_nl
@skip_beq:

    ; ---- Demo 2: BNE ----
    lda #$42
    cmp #$50
    beq @skip_bne
    lda #<msg_bne
    ldx #>msg_bne
    jsr print_str
    jsr print_nl
@skip_bne:

    ; ---- Demo 3: BCC (borrow) ----
    lda #$10
    cmp #$20
    bcs @skip_bcc
    lda #<msg_bcc
    ldx #>msg_bcc
    jsr print_str
    jsr print_nl
@skip_bcc:

    ; ---- Demo 4: BCS (no borrow) ----
    lda #$20
    cmp #$10
    bcc @skip_bcs
    lda #<msg_bcs
    ldx #>msg_bcs
    jsr print_str
    jsr print_nl
@skip_bcs:

    ; ---- Demo 5: If-else chain ----
    lda #<msg_ife
    ldx #>msg_ife
    jsr print_str

    lda #$50
    cmp #$30
    bcc @small
    cmp #$80
    bcs @big

    lda #<msg_mid
    ldx #>msg_mid
    jsr print_str
    jsr print_nl
    jmp @done_ife

@small:
    lda #<msg_small
    ldx #>msg_small
    jsr print_str
    jsr print_nl
    jmp @done_ife

@big:
    lda #<msg_big
    ldx #>msg_big
    jsr print_str
    jsr print_nl

@done_ife:
    lda #0
    rts
