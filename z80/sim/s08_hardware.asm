; s08_hardware.asm - Scenario 8: Hardware Access
; ================================================
; Learning objectives:
;   - Z80 I/O port instructions (IN, OUT)
;   - BDOS fn 12: get CP/M version number
;   - Memory-mapped approach concepts

org 0x0100

_start:
    ld      hl, msg_title
    call    print_str
    call    newline

    ; --- Read CP/M version (BDOS fn 12) ---
    ld      hl, msg_version
    call    print_str
    ld      c, 12             ; BDOS fn 12: get version
    call    0x0005
    ; HL = version (H=major, L=minor)
    ; For CP/M 2.2: HL = 0x0022
    ; For CP/M 3.1: HL = 0x0031
    push    hl
    ld      a, h
    call    print_hex8
    ld      a, l
    call    print_hex8
    call    newline
    pop     hl

    ; --- I/O port demonstration ---
    ; Z80 has IN/OUT instructions for port I/O
    ; In this simulator, ports return 0xFF (floating bus)
    ld      hl, msg_port
    call    print_str
    ld      a, 0x42
    out     (0x00), a         ; write 0x42 to port 0
    in      a, (0x00)         ; read from port 0
    call    print_hex8
    call    newline

    ; --- Multiple ports ---
    ld      hl, msg_ports
    call    print_str
    ld      b, 4
    ld      c, 0
.port_loop:
    in      a, (c)            ; read from port C
    push    bc
    call    print_hex8
    ld      c, 2
    ld      e, ' '
    call    0x0005
    pop     bc
    inc     c
    djnz    .port_loop
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
msg_title:   defm "=== Hardware ===$"
msg_version: defm "CP/M ver: $"
msg_port:    defm "Port 00: $"
msg_ports:   defm "Ports: $"
