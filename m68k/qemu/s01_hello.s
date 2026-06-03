# s01_hello.s - Hello World
# Learning objectives:
#   - m68k bare-metal program structure
#   - Goldfish TTY output at 0xff008000
#   - MOVE.L for MMIO write
#   - BSR/RTS for subroutine calls
#   - BRA for infinite loop halt

.text
.global _start

_start:
    move.l  #0x4000, %sp

    lea     msg1, %a0
    bsr     print_str

halt:
    bra     halt

# ---- Subroutines ----

# print_str: print null-terminated string at a0
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

# putchar: write char in d0 to Goldfish TTY (leaf)
putchar:
    move.l  %d0, 0xff008000
    rts

# ---- Data ----
msg1:
    .asciz "Hello, M68k World!\n"
