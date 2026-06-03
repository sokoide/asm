# s06_serial_in.s - Serial Input
# Learning objectives:
#   - Goldfish TTY receive (REG_BYTES_READY)
#   - DMA buffer read via REG_DATA_PTR / REG_CMD
#   - Polling loop for serial input
#   - Echo characters back to terminal
#   - Enter key (0x0D) to quit

.text
.global _start

_start:
    move.l  #0x4000, %sp

    lea     msg_intro, %a0; bsr print_str

    # Read and echo characters until Enter
.Linput_loop:
    bsr     getchar
    move.l  %d0, %d4
    move.l  %d4, %d0
    bsr     putchar
    cmpi.b  #0x0d, %d4
    beq     .Ldone
    bra     .Linput_loop

.Ldone:
    lea     msg_bye, %a0; bsr print_str

halt:   bra     halt

# ---- Subroutines ----

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

putchar:
    move.l  %d0, 0xff008000
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

# ---- Data ----
.Lrxbuf:
    .space 4
msg_intro: .asciz "Type chars (Enter=quit):\n"
msg_bye:   .asciz "Bye!\n"
