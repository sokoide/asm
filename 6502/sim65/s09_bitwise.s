; s09_bitwise.s - Scenario 9: Bitwise Operations
; =========================================
; Learning objectives:
;   - AND — mask (extract specific bits)
;   - ORA — set bits
;   - EOR — toggle bits
;   - ASL / LSR — shift left/right
;   - ROL / ROR — rotate through carry

; High ZP save location (safe from C runtime which uses $02-$1B)
y_save = $F0

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
str_ptr: .res 2

; ---- Read-only data ----
.segment "RODATA"
msg_hdr: .asciiz "--- Bitwise Operations ---"
msg_and: .asciiz "AND: $FF & $0F = $"
msg_ora: .asciiz "ORA: $F0 | $0F = $"
msg_eor: .asciiz "EOR: $FF ^ $FF = $"
msg_asl: .asciiz "ASL: $41 << 1 = $"
msg_lsr: .asciiz "LSR: $82 >> 1 = $"
msg_rol: .asciiz "ROL: $C0 (C=1) = $"
msg_ror: .asciiz "ROR: $01 (C=1) = $"
nl:      .asciiz ""

; ---- Code ----
.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    lda #$0A
    jsr _putchar

    ; AND
    lda #<msg_and
    ldx #>msg_and
    jsr print_str
    lda #$FF
    and #$0F
    jsr print_hex8
    lda #$0A
    jsr _putchar

    ; ORA
    lda #<msg_ora
    ldx #>msg_ora
    jsr print_str
    lda #$F0
    ora #$0F
    jsr print_hex8
    lda #$0A
    jsr _putchar

    ; EOR
    lda #<msg_eor
    ldx #>msg_eor
    jsr print_str
    lda #$FF
    eor #$FF
    jsr print_hex8
    lda #$0A
    jsr _putchar

    ; ASL
    lda #<msg_asl
    ldx #>msg_asl
    jsr print_str
    lda #$41
    asl a
    jsr print_hex8
    lda #$0A
    jsr _putchar

    ; LSR
    lda #<msg_lsr
    ldx #>msg_lsr
    jsr print_str
    lda #$82
    lsr a
    jsr print_hex8
    lda #$0A
    jsr _putchar

    ; ROL
    lda #<msg_rol
    ldx #>msg_rol
    jsr print_str
    sec
    lda #$C0
    rol a
    jsr print_hex8
    lda #$0A
    jsr _putchar

    ; ROR
    lda #<msg_ror
    ldx #>msg_ror
    jsr print_str
    sec
    lda #$01
    ror a
    jsr print_hex8
    lda #$0A
    jsr _putchar

    lda #0
    rts

; ---- print null-terminated string (A/X = ptr, no newline) ----
print_str:
    sta str_ptr
    stx str_ptr+1
    ldy #0
@ps_loop:
    lda (str_ptr),y
    beq @ps_done
    sty y_save          ; save Y before C call (putchar destroys Y)
    jsr _putchar
    ldy y_save          ; restore Y
    iny
    jmp @ps_loop
@ps_done:
    rts

; ---- print A as 2-digit hex ----
print_hex8:
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    jsr print_nibble
    pla
    and #$0F
    jsr print_nibble
    rts

print_nibble:
    cmp #10
    bcc @digit
    clc
    adc #'A' - '0' - 10
@digit:
    clc
    adc #'0'
    jsr _putchar
    rts
