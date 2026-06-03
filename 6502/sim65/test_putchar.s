.import _putchar
.export _main

.segment "CODE"
_main:
    lda #'A'
    jsr _putchar
    lda #$0A
    jsr _putchar
    lda #0
    rts
