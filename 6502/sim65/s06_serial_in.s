; s06_serial_in.s - Scenario 6: Serial Input
; ========================================
; Learning objectives:
;   - _getchar for keyboard input
;   - Echo characters back via _putchar
;   - Enter key (0x0D) to quit
;   - Character filtering (control chars)

.import print_str, print_nl
.import _putchar, _getchar
.export _main

.segment "RODATA"
msg_intro: .asciiz "Type chars (Enter=quit):"

.segment "CODE"
_main:
    lda #<msg_intro
    ldx #>msg_intro
    jsr print_str
    jsr print_nl

@input_loop:
    jsr _getchar
    cmp #$0D
    beq @done
    cmp #$0A
    beq @done
    jsr _putchar
    jmp @input_loop

@done:
    lda #$0A
    jsr _putchar
    lda #0
    rts
