; s04_loops.asm - Scenario 4: Loops
; ==================================
; Learning objectives:
;   - DJNZ (Decrement B, Jump if Not Zero)
;   - Count-up loop with CP + JP NZ
;   - Nested loops

org 0x0100

_start:
    ; --- Countdown loop (DJNZ) ---
    ld      hl, msg_countdown
    call    print_str
    call    newline

    ld      b, 5              ; count from 5 to 1
.countdown:
    ld      a, '0'
    add     b                 ; digit = '0' + B
    ld      e, a
    push    bc                ; save loop counter (BDOS clobbers B)
    ld      c, 2
    call    0x0005
    ld      c, 2
    ld      e, ' '
    call    0x0005
    pop     bc                ; restore loop counter
    djnz    .countdown
    call    newline

    ; --- Count-up loop ---
    ld      hl, msg_countup
    call    print_str
    call    newline

    ld      b, 0              ; counter starts at 0
.countup:
    ld      a, '0'
    add     b
    ld      e, a
    push    bc                ; save loop counter (BDOS clobbers B)
    ld      c, 2
    call    0x0005
    ld      c, 2
    ld      e, ' '
    call    0x0005
    pop     bc                ; restore loop counter
    inc     b
    ld      a, b
    cp      5                 ; stop when B = 5
    jr      nz, .countup
    call    newline

    ; --- Nested loop (triangle) ---
    ld      hl, msg_nested
    call    print_str
    call    newline

    ld      c, 1              ; outer counter: rows
.outer:
    ld      b, c              ; inner counter: stars per row
.inner:
    push    af
    push    bc
    ld      c, 2
    ld      e, '*'
    call    0x0005
    pop     bc
    pop     af
    djnz    .inner
    call    newline
    inc     c
    ld      a, c
    cp      6                 ; 5 rows
    jr      nz, .outer

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
msg_countdown: defm "Countdown: $"
msg_countup:   defm "Count-up: $"
msg_nested:    defm "Nested:\r\n$"
