; s07_subroutines.asm - Scenario 7: Subroutines
; ==============================================
; Learning objectives:
;   - CALL / RET
;   - Passing arguments via registers
;   - Nested subroutine calls
;   - Register preservation (PUSH/POP)

org 0x0100

_start:
    ; --- Simple call ---
    ld      hl, msg_title
    call    print_str
    call    newline

    ; --- Add two numbers via subroutine ---
    ld      a, 0x25
    ld      b, 0x17
    call    add_ab            ; result in A
    push    af
    ld      hl, msg_add
    call    print_str
    pop     af
    call    print_hex8
    call    newline

    ; --- Nested call: print_sum ---
    ld      a, 0x10
    ld      b, 0x20
    call    print_sum         ; nested: calls add_ab + print_hex8

    ; --- Multiple args via stack ---
    ld      bc, 0x1234
    push    bc
    ld      bc, 0x5678
    push    bc
    call    add_from_stack
    pop     bc                ; clean up args (2 pushes)
    pop     bc

    ret

; ---- Subroutines ----

; add_ab: A = A + B
add_ab:
    add     b
    ret

; print_sum: add A+B and print result
print_sum:
    push    af
    push    bc
    push    de
    call    add_ab
    ld      hl, msg_sum
    call    print_str
    call    print_hex8
    call    newline
    pop     de
    pop     bc
    pop     af
    ret

; add_from_stack: add two 16-bit values from stack
add_from_stack:
    push    ix
    ld      ix, 0
    add     ix, sp
    ld      e, (ix+4)        ; low byte of first arg
    ld      d, (ix+5)        ; high byte of first arg
    ld      l, (ix+6)        ; low byte of second arg
    ld      h, (ix+7)        ; high byte of second arg
    add     hl, de
    push    hl
    ld      hl, msg_stack
    call    print_str
    pop     hl
    ld      a, h
    call    print_hex8
    ld      a, l
    call    print_hex8
    call    newline
    pop     ix
    ret

print_str:
    push    af
    push    bc
    push    de
.ps_loop:
    ld      a, (hl)
    cp      '$'
    jr      z, .ps_done
    ld      c, 2
    ld      e, a
    call    0x0005
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
msg_title: defm "=== Subroutines ===$"
msg_add:   defm "add_ab(25,17) = $"
msg_sum:   defm "print_sum(10,20) = $"
msg_stack: defm "stack(1234,5678) = $"
