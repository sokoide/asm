; s08_hardware.s - Scenario 8: Hardware Timing Concepts
; ========================================
; Learning objectives:
;   - CPU cycle counting: each instruction takes a known number of cycles
;   - NOP = 2 cycles, DEX = 2, BNE(taken) = 3, BNE(not taken) = 2
;   - Calculating total cycles from loop structure
;   - At 1 MHz, 1 cycle = 1 microsecond
;   - No real hardware timer on sim65; pure cycle timing

.import print_str, print_nl, print_dec
.export _main

.segment "RODATA"
msg_hdr:    .asciiz "--- Hardware Timing (Cycle Counting) ---"
msg_fast:   .asciiz "8x(3xNOP+DEX+BNE) = "
msg_cyc:    .asciiz " cycles"
msg_nop:    .asciiz "5x(5xNOP+DEX+BNE) = "
msg_delay:  .asciiz "Nested 256x256: done (326143 cyc ~ 0.33s@1MHz)"

.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    jsr print_nl

    ; ---- Demo 1: Fast loop with cycle calculation ----
    ; Per iteration (BNE taken):  3xNOP(2) + DEX(2) + BNE(3) = 11 cycles
    ; Last iteration (fall thru): 3xNOP(2) + DEX(2) + BNE(2) = 10 cycles
    ; Total: 7 * 11 + 1 * 10 = 87 cycles
    lda #<msg_fast
    ldx #>msg_fast
    jsr print_str

    ldx #8
@fast_loop:
    nop
    nop
    nop
    dex
    bne @fast_loop

    lda #87             ; 7*11 + 10 = 87
    jsr print_dec
    lda #<msg_cyc
    ldx #>msg_cyc
    jsr print_str
    jsr print_nl

    ; ---- Demo 2: NOP-heavy loop ----
    ; Per iteration (BNE taken):  5xNOP(2) + DEX(2) + BNE(3) = 15 cycles
    ; Last iteration (fall thru): 5xNOP(2) + DEX(2) + BNE(2) = 14 cycles
    ; Total: 4 * 15 + 1 * 14 = 74 cycles
    lda #<msg_nop
    ldx #>msg_nop
    jsr print_str

    ldx #5
@nop_loop:
    nop
    nop
    nop
    nop
    nop
    dex
    bne @nop_loop

    lda #74             ; 4*15 + 14 = 74
    jsr print_dec
    lda #<msg_cyc
    ldx #>msg_cyc
    jsr print_str
    jsr print_nl

    ; ---- Demo 3: Nested delay (long wait) ----
    ; Used in real hardware for timing delays
    ; Inner: DEY(2)+BNE(3) * 255 + DEY(2)+BNE(2) = 1274 cycles
    ; Outer: (1274+DEX(2)+BNE(3)) * 255 + (1274+DEX(2)+BNE(2)) = 326,143 cycles
    ; At 1 MHz: ~0.33 seconds
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

    lda #0
    rts
