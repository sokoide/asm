; s11_memory.asm - Scenario 11: Memory Operations
; ================================================
; Learning objectives:
;   - LDIR (block copy)
;   - CPIR (block search)
;   - Memory fill
;   - Indexed addressing (IX, IY)

org 0x0100

_start:
    ld      hl, msg_title
    call    print_str
    call    newline

    ; --- Memory fill ---
    ld      hl, buf1
    ld      a, 0xAA
    ld      b, 8
.fill_loop:
    ld      (hl), a
    inc     hl
    djnz    .fill_loop

    ld      hl, msg_fill
    call    print_str
    ld      hl, buf1
    ld      b, 8
.show_fill:
    ld      a, (hl)
    call    print_hex8
    ld      c, 2
    ld      e, ' '
    call    0x0005
    inc     hl
    djnz    .show_fill
    call    newline

    ; --- LDIR: block copy ---
    ld      hl, buf1
    ld      de, buf2
    ld      bc, 8
    ldir

    ld      hl, msg_copy
    call    print_str
    ld      hl, buf2
    ld      b, 8
.show_copy:
    ld      a, (hl)
    call    print_hex8
    ld      c, 2
    ld      e, ' '
    call    0x0005
    inc     hl
    djnz    .show_copy
    call    newline

    ; --- CPIR: block search ---
    ; Fill buffer with sequential values, then search for 0x05
    ld      hl, buf3
    ld      b, 8
    ld      a, 0
.search_fill:
    ld      (hl), a
    inc     hl
    inc     a
    djnz    .search_fill

    ld      hl, buf3          ; source
    ld      bc, 8             ; length
    ld      a, 5              ; search value
    cpir                      ; search for A in (HL)...
    ; After CPIR: HL points to byte AFTER match
    dec     hl                ; point to match
    ld      hl, msg_search
    call    print_str
    ld      a, (hl)
    call    print_hex8
    call    newline

    ; --- Indexed addressing (IX, IY) ---
    ld      ix, buf3
    ld      a, (ix+3)         ; read 4th element (= 0x03)
    ld      hl, msg_ix
    call    print_str
    call    print_hex8
    call    newline

    ld      iy, buf3
    ld      (iy+3), 0xFF      ; modify 4th element
    ld      a, (iy+3)
    ld      hl, msg_iy
    call    print_str
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
msg_title:  defm "=== Memory ===$"
msg_fill:   defm "Fill: $"
msg_copy:   defm "Copy: $"
msg_search: defm "Found: $"
msg_ix:     defm "IX+3: $"
msg_iy:     defm "IY+3: $"

; Buffers
buf1: defs 16
buf2: defs 16
buf3: defs 16
