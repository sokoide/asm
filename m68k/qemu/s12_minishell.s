# s12_minishell.s - Interactive Mini Shell
# Learning objectives:
#   - Combining all previous concepts into one program
#   - Serial input and output (Goldfish TTY TX/RX)
#   - String comparison for command dispatch
#   - Building a read-eval-print loop (REPL)

.text
.global _start

_start:
    move.l  #0x4000, %sp

    lea     msg_bn, %a0; bsr print_str
    lea     msg_h1, %a0; bsr print_str
    lea     msg_h2, %a0; bsr print_str
    lea     msg_h3, %a0; bsr print_str

.Lmain:
    lea     msg_pr, %a0; bsr print_str
    bsr     read_line
    bsr     print_crlf

    lea     input, %a0
    lea     cmd_hello, %a1
    bsr     strcmp
    beq     .Lhello

    lea     input, %a0
    lea     cmd_help, %a1
    bsr     strcmp
    beq     .Lhelp

    lea     input, %a0
    lea     cmd_quit, %a1
    bsr     strcmp
    beq     .Lquit

    lea     input, %a0
    tst.b   (%a0)
    beq     .Lmain

    lea     msg_unk, %a0; bsr print_str
    bra     .Lmain

.Lhello:
    lea     msg_hi, %a0; bsr print_str
    bra     .Lmain

.Lhelp:
    lea     msg_h1, %a0; bsr print_str
    lea     msg_h2, %a0; bsr print_str
    lea     msg_h3, %a0; bsr print_str
    bra     .Lmain

.Lquit:
    lea     msg_bye, %a0; bsr print_str

halt:   bra     halt

# ---- Subroutines ----

# read_line: read chars into input buffer until Enter
read_line:
    movem.l %d0/%a0/%a1, -(%sp)
    lea     input, %a0
    move.l  %a0, %a1
.Lrl_loop:
    bsr     getchar
    cmpi.b  #0x0d, %d0
    beq     .Lrl_enter
    cmpi.b  #0x0a, %d0
    beq     .Lrl_enter
    cmpi.b  #0x08, %d0
    beq     .Lrl_bs
    cmpi.b  #0x20, %d0
    blt     .Lrl_loop
    move.l  %a0, %d1
    sub.l   %a1, %d1
    cmpi.l  #30, %d1
    bge     .Lrl_loop
    move.b  %d0, (%a0)+
    bsr     putchar
    bra     .Lrl_loop
.Lrl_bs:
    cmpa.l  %a1, %a0
    beq     .Lrl_loop
    subq.l  #1, %a0
    move.l  #0x08, %d0
    bsr     putchar
    move.l  #0x20, %d0
    bsr     putchar
    move.l  #0x08, %d0
    bsr     putchar
    bra     .Lrl_loop
.Lrl_enter:
    move.b  #0, (%a0)
    movem.l (%sp)+, %d0/%a0/%a1
    rts

# getchar: read one char from Goldfish TTY into d0
getchar:
    movem.l %a0, -(%sp)
    lea     .Lrxbuf, %a0
.Lpoll:
    move.l  0xff008004, %d0
    tst.l   %d0
    beq     .Lpoll
    move.l  %a0, 0xff008010
    move.l  #1, 0xff008014
    move.l  #3, 0xff008008
    move.b  (%a0), %d0
    movem.l (%sp)+, %a0
    rts

# strcmp: compare strings at a0 and a1. Z=1 if equal
strcmp:
    movem.l %d0/%d1, -(%sp)
.Lsc_loop:
    move.b  (%a0)+, %d0
    move.b  (%a1)+, %d1
    cmp.b   %d1, %d0
    bne     .Lsc_done
    tst.b   %d0
    beq     .Lsc_done
    bra     .Lsc_loop
.Lsc_done:
    cmp.b   %d1, %d0
    movem.l (%sp)+, %d0/%d1
    rts

print_str:
    movem.l %d0/%a0, -(%sp)
.Lps_loop:
    move.b  (%a0)+, %d0
    tst.b   %d0
    beq     .Lps_done
    bsr     putchar
    bra     .Lps_loop
.Lps_done:
    movem.l (%sp)+, %d0/%a0
    rts

print_crlf:
    movem.l %d0, -(%sp)
    move.l  #0x0d, %d0; bsr putchar
    move.l  #0x0a, %d0; bsr putchar
    movem.l (%sp)+, %d0
    rts

putchar:
    move.l  %d0, 0xff008000
    rts

# ---- Data ----
.Lrxbuf:
    .space 4
msg_bn:  .asciz "M68k MiniShell\n"
msg_pr:  .asciz "> "
msg_hi:  .asciz "Hello, M68k!\n"
msg_h1:  .asciz "Commands: hello, help, quit\n"
msg_h2:  .asciz "  hello - Say hello\n"
msg_h3:  .asciz "  quit  - Exit\n"
msg_bye: .asciz "Bye!\n"
msg_unk: .asciz "Unknown command\n"
cmd_hello: .asciz "hello"
cmd_help:  .asciz "help"
cmd_quit:  .asciz "quit"
input:     .space 32
