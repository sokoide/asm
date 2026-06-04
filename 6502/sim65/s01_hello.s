; s01_hello.s - Scenario 1: Hello World
; ========================================
; Learning objectives:
;   - Program structure (.import, .export, .segment)
;   - C runtime entry point (_main) and return (rts)
;   - String output via print_str (helpers.s)
;   - 16-bit address split (LDA #<addr, LDX #>addr)
;   - Null-terminated string definition (.asciiz)

.import print_str, print_nl
.export _main

.segment "RODATA"
message: .asciiz "Hello, 6502 World!"

.segment "CODE"
_main:
    lda #<message
    ldx #>message
    jsr print_str
    lda #$0A
    jsr print_nl
    lda #0
    rts
