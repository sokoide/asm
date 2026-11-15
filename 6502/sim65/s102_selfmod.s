; s102_selfmod.s - Scenario 102: Self-Modifying Code (arch-specific)
; ===================================================================
; The 6502 has no instruction cache and sim65 runs the CODE segment
; from RAM, so a program can rewrite its own instructions while
; running. The classic trick: patch the operand byte of an immediate
; load instead of keeping the value in a variable.
;
;   self_char:
;       lda #$41      <- operand byte (self_char+1) is patched at runtime
;       jmp _putchar
;
; Writing to self_char+1 changes what the instruction loads on the
; next execution - the operand byte is code AND data at the same time.
;
; Notes:
;   - On real hardware with ROM-resident code this would not work;
;     it needs code living in writable RAM.
;   - The 6502 has no cache, so patched instructions take effect
;     immediately (no cache flush needed).
;   - INC self_char+1 even lets us increment the operand in place,
;     which turns the patched load into a "next character" iterator.

.import print_str, print_nl, _putchar
.export _main

.segment "ZEROPAGE"
x_tmp:      .res 1    ; X save across self_char (clobbers X/Y)

.segment "RODATA"
msg_hdr:    .asciiz "--- Self-Modifying Code ---"
msg_patch:  .asciiz "operand patch: LDA #$41 -> #$5A"
msg_before: .asciiz "  before: "
msg_after:  .asciiz "  after:  "
msg_loop:   .asciiz "INC on code byte: "

.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    jsr print_nl

    lda #<msg_patch
    ldx #>msg_patch
    jsr print_str
    jsr print_nl

; ---- original behavior: prints the assembled operand 'A' ----
    lda #<msg_before
    ldx #>msg_before
    jsr print_str
    jsr self_char          ; prints 'A'
    jsr print_nl

; ---- patch the immediate operand, behavior changes ----
    lda #'Z'
    sta self_char+1        ; rewrite the operand byte in RAM!
    lda #<msg_after
    ldx #>msg_after
    jsr print_str
    jsr self_char          ; prints 'Z'
    jsr print_nl

; ---- loop: increment the operand byte in place ----
    lda #'A'
    sta self_char+1
    lda #<msg_loop
    ldx #>msg_loop
    jsr print_str
    ldx #5
@emit:
    stx x_tmp              ; _putchar clobbers X/Y - save the counter
    jsr self_char          ; prints the current operand char
    inc self_char+1        ; INC abs: bump the code byte itself
    ldx x_tmp
    dex
    bne @emit
    jsr print_nl

    lda #0
    rts

; self_char: print the character stored in its own immediate operand.
; The byte at self_char+1 is data AND code at the same time.
self_char:
    lda #$41               ; operand patched at runtime ($41 = 'A')
    jmp _putchar
