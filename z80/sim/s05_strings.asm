; s05_strings.asm - Scenario 5: Strings
; ======================================
; Learning objectives:
;   - String length (null-terminated)
;   - String copy (LDI / LDIR)
;   - Character-by-character output

org 0x0100

_start:
    ; --- Print a string char by char ---
    ld      hl, msg_title
    call    print_str
    call    newline

    ; --- String length ---
    ld      hl, msg_hello
    call    strlen            ; result in B
    ld      hl, msg_len
    call    print_str
    ld      a, b
    call    print_hex8
    call    newline

    ; --- String copy (LDI) ---
    ld      hl, msg_src
    ld      de, dst_buf
    ld      bc, 6
    ldir                      ; copy BC bytes from HL to DE
    ld      a, '$'
    ld      (de), a           ; null-terminate

    ld      hl, msg_copy
    call    print_str
    ld      hl, dst_buf
    call    print_str
    call    newline

    ; --- Uppercase conversion ---
    ld      hl, msg_lower
    ld      de, dst_buf2
.copy_upper:
    ld      a, (hl)
    cp      '$'
    jr      z, .copy_done
    cp      'a'
    jr      c, .copy_store    ; not lowercase
    cp      'z' + 1
    jr      nc, .copy_store   ; not lowercase
    sub     32                ; convert to uppercase
.copy_store:
    ld      (de), a
    inc     hl
    inc     de
    jr      .copy_upper
.copy_done:
    ld      a, '$'
    ld      (de), a
    ld      hl, msg_upper
    call    print_str
    ld      hl, dst_buf2
    call    print_str
    call    newline

    ret

; ---- Subroutines ----

; strlen: count chars until '$', result in B
strlen:
    push    hl
    ld      b, 0
.sl_loop:
    ld      a, (hl)
    cp      '$'
    jr      z, .sl_done
    inc     hl
    inc     b
    jr      .sl_loop
.sl_done:
    pop     hl
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
msg_title: defm "=== Strings ===$"
msg_hello: defm "Hello$"
msg_len:   defm "Len = $"
msg_src:   defm "World"
msg_copy:  defm "Copy: $"
msg_lower: defm "hello$"
msg_upper: defm "Upper: $"

; Buffers
dst_buf:  defs 32
dst_buf2: defs 32
