; s11_memory.s — Memory and Array Operations
; Learning objectives:
;   - Array access with base + X/Y index
;   - Block copy: loop-based memory transfer
;   - Memory fill: fill region with specified byte
;   - Sum with 16-bit carry
;   - Buffer read/write patterns

.import print_str, print_nl, print_hex8
.import _putchar
.export _main

.segment "ZEROPAGE"
sum_lo:  .res 1
sum_hi:  .res 1
tmp_x:   .res 1

.segment "RODATA"
msg_hdr:  .asciiz "--- Memory Operations ---"
msg_src:  .asciiz "Source:      "
msg_dst:  .asciiz "Copy:        "
msg_fill: .asciiz "Fill $AA:    "
msg_sum:  .asciiz "Array sum:   $"

.segment "BSS"
src_array: .res 8
dst_array: .res 8

.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    jsr print_nl

    ; ---- Initialize source array ----
    ldx #0
    lda #$10
@init_loop:
    sta src_array,x
    clc
    adc #$10
    inx
    cpx #8
    bne @init_loop

    ; ---- Print source array ----
    lda #<msg_src
    ldx #>msg_src
    jsr print_str
    ldx #0
@print_src:
    stx tmp_x
    lda src_array,x
    jsr print_hex8
    lda #' '
    jsr _putchar
    ldx tmp_x
    inx
    cpx #8
    bne @print_src
    jsr print_nl

    ; ---- Block copy: src -> dst ----
    ldx #0
@copy_loop:
    lda src_array,x
    sta dst_array,x
    inx
    cpx #8
    bne @copy_loop

    ; ---- Print copy result ----
    lda #<msg_dst
    ldx #>msg_dst
    jsr print_str
    ldx #0
@print_dst:
    stx tmp_x
    lda dst_array,x
    jsr print_hex8
    lda #' '
    jsr _putchar
    ldx tmp_x
    inx
    cpx #8
    bne @print_dst
    jsr print_nl

    ; ---- Memory fill: dst with $AA ----
    ldx #0
    lda #$AA
@fill_loop:
    sta dst_array,x
    inx
    cpx #8
    bne @fill_loop

    ; ---- Print fill result ----
    lda #<msg_fill
    ldx #>msg_fill
    jsr print_str
    ldx #0
@print_fill:
    stx tmp_x
    lda dst_array,x
    jsr print_hex8
    lda #' '
    jsr _putchar
    ldx tmp_x
    inx
    cpx #8
    bne @print_fill
    jsr print_nl

    ; ---- Sum src_array with 16-bit carry ----
    clc
    lda #0
    sta sum_lo
    sta sum_hi
    ldx #0
@sum_loop:
    clc
    lda sum_lo
    adc src_array,x
    sta sum_lo
    lda sum_hi
    adc #0
    sta sum_hi
    inx
    cpx #8
    bne @sum_loop

    ; ---- Print sum ----
    lda #<msg_sum
    ldx #>msg_sum
    jsr print_str
    lda sum_hi
    jsr print_hex8
    lda sum_lo
    jsr print_hex8
    jsr print_nl

    lda #0
    rts
