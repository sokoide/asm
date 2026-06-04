; s08_hardware.s — Hardware Timing Concepts
; Learning objectives:
;   - CPU cycle counting via NOP-based delay loops
;   - Timing estimation: each NOP = 2 cycles
;   - Observing different loop iteration speeds
;   - No real hardware timer on sim65; pure cycle timing

.import print_str, print_nl, print_hex8
.import _putchar
.export _main

.segment "ZEROPAGE"
counter: .res 1
result:  .res 1

.segment "RODATA"
msg_hdr:   .asciiz "--- Hardware Timing (Cycle Counting) ---"
msg_delay: .asciiz "1 ms delay loop: done"
msg_fast:  .asciiz "Fast loop (10 iters): done"
msg_nop:   .asciiz "NOP x5 inner loop: done"

.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    jsr print_nl

    ; ---- Demo 1: Simple delay loop ----
    lda #<msg_delay
    ldx #>msg_delay
    jsr print_str
    jsr print_nl

    ldx #$FF
@delay_outer:
    ldy #$FF
@delay_inner:
    dey
    bne @delay_inner
    dex
    bne @delay_outer

    ; ---- Demo 2: Fast counted loop ----
    lda #<msg_fast
    ldx #>msg_fast
    jsr print_str
    jsr print_nl

    ldx #10
@fast_loop:
    nop
    nop
    nop
    dex
    bne @fast_loop

    ; ---- Demo 3: NOP sequence demo ----
    lda #<msg_nop
    ldx #>msg_nop
    jsr print_str
    jsr print_nl

    ldx #5
@nop_loop:
    nop
    nop
    nop
    nop
    nop
    dex
    bne @nop_loop

    lda #0
    rts
