; s09_branching.asm - Scenario 9: Conditional Branching
; ======================================================
; Learning objectives:
;   - CP instruction + flag register
;   - JP Z/NZ/C/NC/M/P (conditional jumps)
;   - JR (relative jump)
;   - Branch table via JP (HL)

org 0x0100

_start:
    ld      hl, msg_title
    call    print_str
    call    newline

    ; --- Compare and branch ---
    ld      a, 5
    cp      10                ; compare A with 10
    jr      c, .a_less        ; A < 10 (carry set)
    ld      hl, msg_ge
    call    print_str
    jr      .cmp_done
.a_less:
    ld      hl, msg_lt
    call    print_str
.cmp_done:
    call    newline

    ; --- Multiple conditions ---
    ld      b, 3
    ld      a, b
    cp      0
    jr      z, .is_zero
    cp      3
    jr      z, .is_three
    ld      hl, msg_other
    call    print_str
    jr      .multi_done
.is_zero:
    ld      hl, msg_zero
    call    print_str
    jr      .multi_done
.is_three:
    ld      hl, msg_three
    call    print_str
.multi_done:
    call    newline

    ; --- Branch table (JP (HL)) ---
    ; Select message based on index
    ld      a, 2              ; index = 2
    cp      0
    jr      nz, .bt_check1
    ld      hl, msg_opt0
    jr      .bt_show
.bt_check1:
    cp      1
    jr      nz, .bt_check2
    ld      hl, msg_opt1
    jr      .bt_show
.bt_check2:
    cp      2
    jr      nz, .bt_default
    ld      hl, msg_opt2
    jr      .bt_show
.bt_default:
    ld      hl, msg_optX
.bt_show:
    ld      de, msg_branch
    call    print_str_de
    call    print_str         ; HL already set
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

; print_str_de: print string at DE (preserves HL)
print_str_de:
    push    af
    push    bc
    push    hl
    ex      de, hl
.psde_loop:
    ld      a, (hl)
    cp      '$'
    jr      z, .psde_done
    ld      c, 2
    push    hl
    ld      e, a
    call    0x0005
    pop     hl
    inc     hl
    jr      .psde_loop
.psde_done:
    pop     hl
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
msg_title:  defm "=== Branching ===$"
msg_lt:     defm "5 < 10: Yes$"
msg_ge:     defm "5 >= 10: No$"
msg_zero:   defm "Value is 0$"
msg_three:  defm "Value is 3$"
msg_other:  defm "Value is other$"
msg_branch: defm "Branch[2]: $"
msg_opt0:   defm "Option A$"
msg_opt1:   defm "Option B$"
msg_opt2:   defm "Option C$"
msg_optX:   defm "Unknown$"
