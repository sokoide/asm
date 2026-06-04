; s10_bitwise.s - Scenario 10: Bitwise Operations
; ========================================
; Learning objectives:
;   - AND — mask (extract specific bits)
;   - ORA — set bits
;   - EOR — toggle bits
;   - ASL / LSR — shift left/right
;   - ROL / ROR — rotate through carry

.import print_str, print_nl, print_hex8
.import _putchar
.export _main

.segment "RODATA"
msg_hdr: .asciiz "--- Bitwise Operations ---"
msg_and: .asciiz "AND: $FF & $0F = $"
msg_ora: .asciiz "ORA: $F0 | $0F = $"
msg_eor: .asciiz "EOR: $FF ^ $FF = $"
msg_asl: .asciiz "ASL: $41 << 1 = $"
msg_lsr: .asciiz "LSR: $82 >> 1 = $"
msg_rol: .asciiz "ROL: $C0 (C=1) = $"
msg_ror: .asciiz "ROR: $01 (C=1) = $"

.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    jsr print_nl

    ; AND
    lda #<msg_and
    ldx #>msg_and
    jsr print_str
    lda #$FF
    and #$0F
    jsr print_hex8
    jsr print_nl

    ; ORA
    lda #<msg_ora
    ldx #>msg_ora
    jsr print_str
    lda #$F0
    ora #$0F
    jsr print_hex8
    jsr print_nl

    ; EOR
    lda #<msg_eor
    ldx #>msg_eor
    jsr print_str
    lda #$FF
    eor #$FF
    jsr print_hex8
    jsr print_nl

    ; ASL
    lda #<msg_asl
    ldx #>msg_asl
    jsr print_str
    lda #$41
    asl a
    jsr print_hex8
    jsr print_nl

    ; LSR
    lda #<msg_lsr
    ldx #>msg_lsr
    jsr print_str
    lda #$82
    lsr a
    jsr print_hex8
    jsr print_nl

    ; ROL
    lda #<msg_rol
    ldx #>msg_rol
    jsr print_str
    sec
    lda #$C0
    rol a
    jsr print_hex8
    jsr print_nl

    ; ROR
    lda #<msg_ror
    ldx #>msg_ror
    jsr print_str
    sec
    lda #$01
    ror a
    jsr print_hex8
    jsr print_nl

    lda #0
    rts
