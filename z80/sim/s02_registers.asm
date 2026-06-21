; s02_registers.asm - Scenario 2: Registers
; ===========================================
; Learning objectives:
;   - Z80 registers: A, B, C, D, E, H, L
;   - 16-bit register pairs: BC, DE, HL
;   - LD, ADD, SUB, INC, DEC
;   - Display register values as hex

org 0x0100

_start:
    ; --- 8-bit operations ---
    ld      a, 0x10           ; A = 0x10
    ld      b, 0x20           ; B = 0x20
    add     a, b              ; A = A + B = 0x30

    ld      hl, msg_add
    call    print_str
    call    print_hex8        ; print A (0x30)
    call    newline

    ld      c, 0x05
    dec     c                 ; C = 0x04
    ld      a, c
    ld      hl, msg_dec
    call    print_str
    call    print_hex8
    call    newline

    ; --- 16-bit operations ---
    ld      hl, 0x0000        ; HL を明示的に 0 に初期化
    ld      bc, 0x1234
    add     hl, bc            ; HL = HL + BC = 0x1234 (16-bit 加算の例)
    ld      hl, msg_16
    call    print_str
    ld      a, b              ; BC の上位バイト
    call    print_hex8
    ld      a, c              ; BC の下位バイト
    call    print_hex8
    call    newline

    ; --- Increment 16-bit ---
    ld      hl, 0x00FF
    inc     hl                ; HL = 0x0100
    push    hl                ; 結果を退避（print_str が HL を破壊するため）
    ld      hl, msg_inc
    call    print_str
    pop     hl                ; 結果を復元
    ld      a, h
    call    print_hex8
    ld      a, l
    call    print_hex8
    call    newline

    ret

; ---- Subroutines ----

print_str:
    push    af
    push    bc
    push    de
.ps_loop:
    ld      a, (hl)
    cp      '$'
    jr      z, .ps_done
    ld      c, 2
    push    hl
    ld      e, a
    call    0x0005
    pop     hl
    inc     hl
    jr      .ps_loop
.ps_done:
    pop     de
    pop     bc
    pop     af
    ret

; print_hex8: print A as 2 hex digits
print_hex8:
    push    af
    push    bc
    ld      b, a
    ; high nibble
    rrca
    rrca
    rrca
    rrca
    call    hex_nibble
    ld      c, 2
    ld      e, a
    call    0x0005
    ; low nibble
    ld      a, b
    call    hex_nibble
    ld      c, 2
    ld      e, a
    call    0x0005
    pop     bc
    pop     af
    ret

hex_nibble:
    and     0x0F
    cp      10
    jr      c, .hn_dec
    add     'A' - 10
    ret
.hn_dec:
    add     '0'
    ret

newline:
    push    af
    push    bc
    push    de
    ld      c, 2
    ld      e, 13
    call    0x0005
    ld      c, 2
    ld      e, 10
    call    0x0005
    pop     de
    pop     bc
    pop     af
    ret

; ---- Data ----
msg_add:  defm "ADD A,B = $"
msg_dec:  defm "DEC C   = $"
msg_16:   defm "BC      = $"
msg_inc:  defm "INC HL  = $"
