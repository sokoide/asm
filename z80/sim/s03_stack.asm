; s03_stack.asm - Scenario 3: Stack
; ==================================
; Learning objectives:
;   - PUSH/POP (AF, BC, DE, HL)
;   - SP (Stack Pointer) operations
;   - LIFO (Last In, First Out) behavior

org 0x0100

_start:
    ; --- Push and Pop ---
    ld      hl, msg_title
    call    print_str
    call    newline

    ; Push AF with value 0x42
    ld      a, 0x42
    push    af

    ; Push BC with value 0x1234
    ld      bc, 0x1234
    push    bc

    ; Modify registers
    ld      a, 0x00
    ld      bc, 0x0000

    ; Pop BC (should be 0x1234) - LIFO!
    pop     bc
    ld      hl, msg_bc
    call    print_str
    ld      a, b
    call    print_hex8
    ld      a, c
    call    print_hex8
    call    newline

    ; Pop AF (should be 0x42)
    pop     af
    ld      hl, msg_af
    call    print_str
    call    print_hex8
    call    newline

    ; --- Nested push/pop ---
    ld      hl, msg_nest
    call    print_str
    call    newline

    ld      de, 0xAABB
    push    de
    ld      hl, 0xCCDD
    push    hl
    pop     de                ; DE = 0xCCDD (LIFO)
    ld      hl, msg_inner
    call    print_str
    ld      a, d
    call    print_hex8
    ld      a, e
    call    print_hex8
    call    newline
    pop     de                ; DE = 0xAABB
    ld      hl, msg_outer
    call    print_str
    ld      a, d
    call    print_hex8
    ld      a, e
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
msg_title: defm "=== Stack Demo ===$"
msg_bc:    defm "POP BC  = $"
msg_af:    defm "POP AF  = $"
msg_nest:  defm "--- Nested ---$"
msg_inner: defm "Inner DE= $"
msg_outer: defm "Outer DE= $"
