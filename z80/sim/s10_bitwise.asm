; s10_bitwise.asm - Scenario 10: Bitwise Operations
; ==================================================
; Learning objectives:
;   - AND, OR, XOR, CPL
;   - Shifts: RLC, RRC, SLA, SRA, SRL
;   - BIT, SET, RES
;   - Masking techniques

org 0x0100

_start:
    ld      hl, msg_title
    call    print_str
    call    newline

    ; --- AND: mask lower nibble ---
    ld      a, 0xA5
    and     0x0F              ; keep lower nibble
    ld      hl, msg_and
    call    print_str
    call    print_hex8
    call    newline

    ; --- OR: combine nibbles ---
    ld      a, 0x50
    or      0x03              ; combine
    ld      hl, msg_or
    call    print_str
    call    print_hex8
    call    newline

    ; --- XOR: toggle bits ---
    ld      a, 0xFF
    xor     0x0F              ; toggle lower 4 bits
    ld      hl, msg_xor
    call    print_str
    call    print_hex8
    call    newline

    ; --- CPL: complement ---
    ld      a, 0x55
    cpl                       ; A = 0xAA
    ld      hl, msg_cpl
    call    print_str
    call    print_hex8
    call    newline

    ; --- Shifts ---
    ld      a, 0x81

    ; SLA (shift left, fill 0)
    sla     a                 ; A = 0x02
    ld      hl, msg_sla
    call    print_str
    call    print_hex8
    call    newline

    ; SRA (shift right, keep sign)
    ld      a, 0x82
    sra     a                 ; A = 0x41
    ld      hl, msg_sra
    call    print_str
    call    print_hex8
    call    newline

    ; SRL (shift right, fill 0)
    ld      a, 0x82
    srl     a                 ; A = 0x41
    ld      hl, msg_srl
    call    print_str
    call    print_hex8
    call    newline

    ; --- BIT / SET / RES ---
    ld      a, 0x00
    set     3, a              ; set bit 3 -> A = 0x08
    ld      hl, msg_set
    call    print_str
    call    print_hex8
    call    newline

    res     3, a              ; clear bit 3 -> A = 0x00
    ld      hl, msg_res
    call    print_str
    call    print_hex8
    call    newline

    ; BIT test (sets Z flag)
    ld      a, 0x42
    bit     6, a              ; bit 6 of 0x42 = 1 -> Z=0
    jr      nz, .bit_set
    ld      hl, msg_bit_clear
    call    print_str
    jr      .bit_done
.bit_set:
    ld      hl, msg_bit_set
    call    print_str
.bit_done:
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

print_hex8:
    push    bc
    ld      b, a
    rrca
    rrca
    rrca
    rrca
    call    hex_nibble
    ld      c, 2
    ld      e, a
    call    0x0005
    ld      a, b
    call    hex_nibble
    ld      c, 2
    ld      e, a
    call    0x0005
    pop     bc
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
msg_title:    defm "=== Bitwise ===$"
msg_and:      defm "AND A5,0F = $"
msg_or:       defm "OR  50,03 = $"
msg_xor:      defm "XOR FF,0F = $"
msg_cpl:      defm "CPL 55    = $"
msg_sla:      defm "SLA 81    = $"
msg_sra:      defm "SRA 82    = $"
msg_srl:      defm "SRL 82    = $"
msg_set:      defm "SET 3,00  = $"
msg_res:      defm "RES 3,08  = $"
msg_bit_set:  defm "BIT 6,42 = 1$"
msg_bit_clear: defm "BIT 6,42 = 0$"
