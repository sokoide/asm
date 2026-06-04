; s12_minishell.asm - Scenario 12: Interactive Mini Shell
; =======================================================
; Learning objectives:
;   - BDOS fn 10: read console buffer
;   - Command parsing and string comparison
;   - Command dispatch loop
;   - Interactive program structure

org 0x0100

_start:
    ; Print welcome
    ld      hl, msg_welcome
    call    print_str
    call    newline
    ld      hl, msg_help
    call    print_str
    call    newline

    ; Main loop
.main_loop:
    ; Print prompt
    ld      c, 2
    ld      e, '>'
    call    0x0005
    ld      c, 2
    ld      e, ' '
    call    0x0005

    ; Read input line
    ld      de, inbuf
    ld      a, 32             ; max length
    ld      (de), a
    ld      c, 10             ; BDOS fn 10: read console buffer
    call    0x0005

    ; Get actual length
    ld      a, (inbuf+1)
    cp      0
    jr      z, .main_loop     ; empty line

    ; Null-terminate for easier comparison
    ld      hl, inbuf+2
    ld      d, 0
    ld      e, a
    add     hl, de
    ld      (hl), '$'

    ; Compare commands
    ld      hl, inbuf+2

    ; "help"
    ld      de, cmd_help
    call    strcmp
    jr      z, .do_help

    ; "hello"
    ld      hl, inbuf+2
    ld      de, cmd_hello
    call    strcmp
    jr      z, .do_hello

    ; "regs"
    ld      hl, inbuf+2
    ld      de, cmd_regs
    call    strcmp
    jr      z, .do_regs

    ; "quit" or "q"
    ld      hl, inbuf+2
    ld      de, cmd_quit
    call    strcmp
    jr      z, .do_quit
    ld      hl, inbuf+2
    ld      de, cmd_q
    call    strcmp
    jr      z, .do_quit

    ; Unknown command
    ld      hl, msg_unknown
    call    print_str
    ld      hl, inbuf+2
    call    print_str
    call    newline
    jr      .main_loop

.do_help:
    ld      hl, msg_help
    call    print_str
    call    newline
    jp      .main_loop

.do_hello:
    ld      hl, msg_hello
    call    print_str
    call    newline
    jp      .main_loop

.do_regs:
    ld      hl, msg_reg_a
    call    print_str
    call    print_hex8
    ld      hl, msg_reg_b
    call    print_str
    push    bc
    ld      a, b
    call    print_hex8
    pop     bc
    call    newline
    jp      .main_loop

.do_quit:
    ld      hl, msg_bye
    call    print_str
    call    newline
    ret

; ---- Subroutines ----

; strcmp: compare $-terminated strings at HL and DE
; Z flag set if equal
strcmp:
    push    hl
    push    de
.sc_loop:
    ld      a, (de)
    cp      '$'
    jr      z, .sc_check_end
    cp      (hl)
    jr      nz, .sc_ne
    inc     hl
    inc     de
    jr      .sc_loop
.sc_check_end:
    ld      a, (hl)
    cp      '$'
    jr      z, .sc_eq
.sc_ne:
    or      1                 ; clear Z flag
    jr      .sc_done
.sc_eq:
    xor     a                 ; set Z flag
.sc_done:
    pop     de
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
msg_welcome: defm "Z80 Mini Shell - type 'help' for commands$"
msg_help:    defm "Commands: help, hello, regs, quit$"
msg_hello:   defm "Hello from Z80!$"
msg_bye:     defm "Goodbye!$"
msg_unknown: defm "Unknown: $"
msg_reg_a:   defm "A=$"
msg_reg_b:   defm " B=$"

cmd_help:    defm "help$"
cmd_hello:   defm "hello$"
cmd_regs:    defm "regs$"
cmd_quit:    defm "quit$"
cmd_q:       defm "q$"

; Input buffer: [max_len] [actual_len] [chars...]
inbuf: defs 36
