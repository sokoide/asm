# s13_copybench.s - Copy Benchmark (common to all architectures)
# Learning objectives:
#   - MOVE.B (An)+,(An)+: byte transfer using post-increment addressing
#   - DBRA (DBF): loop counter without a separate compare
#   - Measuring copy cost: hand-calculated 68000 cycle counts (QEMU TCG cannot
#     measure cycles, so the breakdown is documented in comments below)
#   - Checksum verification of a 100-byte memory copy
#
# Task (common spec across architectures):
#   - Copy 100 bytes where byte i = i (0..99)
#   - Sum the 100 destination bytes (checksum of 0+1+...+99 = 4950 = 0x1356)
#   - Output exactly one line: "COPY OK CHECKSUM=1356"
#     (or "COPY FAIL CHECKSUM=xxxx" on mismatch)
#
# ---- Cycle breakdown of the COPY BODY (hand calculation) ----
# Basis: MC68000 User's Manual instruction timing table (MOVE.B (An)+,(An)+
#        memory-to-memory byte move = 12 cycles; LEA (abs),An = 8 cycles;
#        MOVE.W #imm,Dn = 8 cycles) and the isa CLI (`isa m68k DBcc`:
#        loop taken = 10, loop exit = 14).
#   lea     src, %a0         =   8
#   lea     dst, %a1         =   8
#   move.w  #99, %d2         =   8
#   move.b  (%a0)+, (%a1)+   =  12 x 100        = 1200
#   dbra    %d2, .Lcopy      =  10 x 99 + 14    = 1014
#   copy body total          = 8 + 8 + 8 + 1200 + 1014 = 2238 cycles
#
# Note: the 68000 has no block-transfer instruction (no 8086 REP MOVSB /
# Z80 LDIR equivalent). 12 cycles/byte makes the (An)+,(An)+ move the
# canonical tight loop; a MOVE.L version copies 4 bytes per 16-cycle
# iteration but needs word/longword alignment handling.
#
# ---- Cycle breakdown of the CHECKSUM LOOP (hand calculation) ----
#   lea     dst, %a0         =   8
#   clr.l   %d1              =   4
#   clr.l   %d0              =   4
#   move.w  #99, %d2         =   8
#   per iteration:           move.b (a0)+,d0(8) + add.w d0,d1(4) + dbra(10)
#                            = 22 x 99                          = 2178
#   final iteration:         move.b(8) + add.w(4) + dbra exit(14) = 26
#   checksum total           = 8 + 4 + 4 + 8 + 2178 + 26 = 2228 cycles
# (I/O and print routines are excluded: their cost is TTY-speed dependent.)

.text
.global _start

_start:
    move.l  #0x4000, %sp

    # --- Build source data: byte i = i (0..99) ---
    lea     src, %a0
    clr.l   %d0
    move.w  #99, %d2
.Lfill:
    move.b  %d0, (%a0)+
    addq.b  #1, %d0
    dbra    %d2, .Lfill

    # --- Copy body: MOVE.B (A0)+,(A1)+ loop (2238 cycles, see above) ---
    lea     src, %a0
    lea     dst, %a1
    move.w  #99, %d2
.Lcopy:
    # dst <- src, both pointers advance
    move.b  (%a0)+, (%a1)+
    # D2--, loop while D2 != -1
    dbra    %d2, .Lcopy

    # --- Checksum: sum 100 destination bytes (16-bit accumulator) ---
    lea     dst, %a0
    clr.l   %d1
    clr.l   %d0
    move.w  #99, %d2
.Lsum:
    move.b  (%a0)+, %d0
    add.w   %d0, %d1
    dbra    %d2, .Lsum

    # --- Verify and print result ---
    # 0+1+...+99 = 4950 = 0x1356
    cmpi.l  #0x1356, %d1
    bne     .fail

    lea     msg_ok, %a0
    bsr     print_str
    move.l  %d1, %d0
    bsr     print_hex16
    bsr     print_crlf
    bra     .halt

.fail:
    lea     msg_fail, %a0
    bsr     print_str
    move.l  %d1, %d0
    bsr     print_hex16
    bsr     print_crlf

.halt:  bra     halt

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

print_hex16:
    # low word of D0 in 4 hex digits
    movem.l %d0-%d2, -(%sp)
    move.l  %d0, %d1
    moveq   #12, %d2
.Lph_loop:
    move.l  %d1, %d0
    lsr.l   %d2, %d0
    and.l   #0xf, %d0
    cmpi.b  #9, %d0
    ble     .Lph_digit
    addq.b  #7, %d0
.Lph_digit:
    addi.b  #'0', %d0
    bsr     putchar
    subq.l  #4, %d2
    bpl     .Lph_loop
    movem.l (%sp)+, %d0-%d2
    rts

print_crlf:
    movem.l %d0, -(%sp)
    move.l  #0x0d, %d0; bsr putchar
    move.l  #0x0a, %d0; bsr putchar
    movem.l (%sp)+, %d0
    rts

putchar:
    # leaf: write char in D0 to Goldfish TTY
    move.l  %d0, 0xff008000
    rts

# ---- Data ----
msg_ok:   .asciz "COPY OK CHECKSUM="
msg_fail: .asciz "COPY FAIL CHECKSUM="
src:      .space 100
dst:      .space 100
