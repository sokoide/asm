; s03_stack.s — Stack Operations
; Learning objectives:
;   - Stack page: $0100-$01FF (fixed 256 bytes, grows downward)
;   - PHA / PLA — push/pull accumulator
;   - TXS / TSX — set/check stack pointer
;   - Register save/restore pattern (PHA -> work -> PLA)

.import print_str, print_nl, print_hex8
.export _main

.segment "ZEROPAGE"
sp_before: .res 1
sp_after:  .res 1
val1:      .res 1
val2:      .res 1

.segment "RODATA"
msg_sp1:   .asciiz "SP: $01"
msg_sp2:   .asciiz " -> $01"
msg_lifo1: .asciiz "LIFO: pull #1=$"
msg_lifo2: .asciiz " pull #2=$"
msg_save:  .asciiz "Save/restore: push $42 -> overwrite -> pull=$"

.segment "CODE"
_main:
    ; ---- Demo 1: Stack pointer movement ----
    tsx
    stx sp_before

    lda #$AA
    pha
    lda #$CC
    pha

    tsx
    stx sp_after

    lda #<msg_sp1
    ldx #>msg_sp1
    jsr print_str
    lda sp_before
    jsr print_hex8

    lda #<msg_sp2
    ldx #>msg_sp2
    jsr print_str
    lda sp_after
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 2: LIFO order ----
    pla
    sta val1
    pla
    sta val2

    lda #<msg_lifo1
    ldx #>msg_lifo1
    jsr print_str
    lda val1
    jsr print_hex8

    lda #<msg_lifo2
    ldx #>msg_lifo2
    jsr print_str
    lda val2
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 3: Save/restore ----
    lda #$42
    pha
    lda #$FF
    pla
    sta val1

    lda #<msg_save
    ldx #>msg_save
    jsr print_str
    lda val1
    jsr print_hex8
    jsr print_nl

    lda #0
    rts
