; s06_serial_in.asm - Scenario 6: Serial Input
; ==============================================
; Learning objectives:
;   - BDOS fn 1: console input (blocking read)
;   - Echo characters back to terminal
;   - Enter key (CR = 0x0D) to quit

org 0x0100

_start:
    ld      hl, msg_intro
    call    print_str
    call    newline

    ; Read and echo characters until Enter
.input_loop:
    ld      c, 1              ; BDOS fn 1: console input
    call    0x0005
    ; A = received character (already echoed by BDOS)
    cp      13                ; CR = Enter?
    jr      z, .done
    cp      10                ; LF?
    jr      z, .done
    jr      .input_loop

.done:
    call    newline
    ld      hl, msg_bye
    call    print_str
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
msg_intro: defm "Type chars (Enter=quit):$"
msg_bye:   defm "Bye!$"
