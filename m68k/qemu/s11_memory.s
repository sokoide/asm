# s11_memory.s - Memory Operations
# Learning objectives:
#   - MOVE.B for byte load/store
#   - Post-increment addressing mode (a0)+
#   - Implementing memset and memcpy in assembly
#   - .space directive for uninitialized memory

.text
.global _start

_start:
    move.l  #0x4000, %sp

    # memset: fill buffer with 'X'
    lea     msg_f, %a0; bsr print_str
    lea     buf1, %a0
    move.l  #0x58, %d1
    move.l  #5, %d2
    bsr     my_memset
    # Print filled buffer
    lea     buf1, %a0
    move.l  #5, %d3
.Lfp_loop:
    move.b  (%a0)+, %d0
    bsr     putchar
    move.l  #0x20, %d0; bsr putchar
    subq.l  #1, %d3
    bne     .Lfp_loop
    bsr     print_crlf

    # memcpy: copy "Hello" into buffer
    lea     msg_c, %a0; bsr print_str
    lea     buf2, %a0
    lea     src, %a1
    bsr     my_memcpy
    lea     buf2, %a0; bsr print_str
    bsr     print_crlf

    # Post-increment addressing demo
    lea     msg_pi, %a0; bsr print_str
    lea     src, %a0
    move.l  #5, %d3
.Lpi_loop:
    move.b  (%a0)+, %d0
    bsr     putchar
    subq.l  #1, %d3
    bne     .Lpi_loop
    bsr     print_crlf

halt:   bra     halt

# ---- Subroutines ----

# my_memset: fill a0 (dst) with d1 (byte) for d2 (count)
my_memset:
    movem.l %d0/%a0, -(%sp)
.Lms_loop:
    tst.l   %d2
    beq     .Lms_done
    move.b  %d1, (%a0)+
    subq.l  #1, %d2
    bra     .Lms_loop
.Lms_done:
    movem.l (%sp)+, %d0/%a0
    rts

# my_memcpy: copy string from a1 (src) to a0 (dst)
my_memcpy:
    movem.l %d0/%a0/%a1, -(%sp)
.Lmc_loop:
    move.b  (%a1)+, %d0
    move.b  %d0, (%a0)+
    tst.b   %d0
    bne     .Lmc_loop
    movem.l (%sp)+, %d0/%a0/%a1
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
msg_f:  .asciz "Fill:  "
msg_c:  .asciz "Copy:  "
msg_pi: .asciz "Post-inc: "
src:    .asciz "Hello"
buf1:   .space 32
buf2:   .space 32
