; s13_copybench.s - Scenario 13: Copy Bench (100-byte memory copy)
; =================================================================
; Common benchmark scenario (same spec on every architecture):
;   - Copy 100 bytes (byte i = i) from src to dst with a naive
;     byte loop (LDA/STA + absolute,X indexing)
;   - Verify dst against src and sum the 100 destination bytes into
;     a 16-bit checksum
;   - Print exactly one line:
;       COPY OK CHECKSUM=1356      (0+1+...+99 = 4950 = $1356)
;       COPY FAIL CHECKSUM=xxxx    (on mismatch)
;
; Learning objectives:
;   - absolute,X indexed copy loop
;   - 16-bit accumulation with ADC #0 carry propagation
;   - cross-architecture size/cycle comparison via .lst / make cycles
;
; Cycle cost per instruction (6502 datasheet, sim65 counts exactly):
;   copy loop : LDA abs,X = 4 / STA abs,X = 5 / INX = 2 /
;               CPX # = 2 / BNE = 3 taken, 2 not taken
;               -> 16 cycles per byte, 16 x 99 + 15 = 1599 cycles
;   check loop: LDA abs,X = 4 / CMP abs,X = 4 / BNE = 2 (not taken) /
;               CLC = 2 / ADC zp = 3 / STA zp = 3 / LDA zp = 3 /
;               ADC # = 2 / STA zp = 3 / INX = 2 / CPX # = 2 /
;               BNE = 3 taken -> 33 cycles per byte

.import print_str, print_nl, print_hex8
.export _main

.segment "ZEROPAGE"
sum_lo:     .res 1
sum_hi:     .res 1

.segment "RODATA"
msg_ok:     .asciiz "COPY OK CHECKSUM="
msg_fail:   .asciiz "COPY FAIL CHECKSUM="
src_data:   .byte  0, 1, 2, 3, 4, 5, 6, 7, 8, 9
.byte 10,11,12,13,14,15,16,17,18,19
.byte 20,21,22,23,24,25,26,27,28,29
.byte 30,31,32,33,34,35,36,37,38,39
.byte 40,41,42,43,44,45,46,47,48,49
.byte 50,51,52,53,54,55,56,57,58,59
.byte 60,61,62,63,64,65,66,67,68,69
.byte 70,71,72,73,74,75,76,77,78,79
.byte 80,81,82,83,84,85,86,87,88,89
.byte 90,91,92,93,94,95,96,97,98,99

.segment "BSS"
dst_buf:    .res 100

.segment "CODE"
_main:
; ---- naive byte copy (absolute,X) ----
    ldx #0
@copy:
    lda src_data,x     ; 4
    sta dst_buf,x      ; 5
    inx                ; 2
    cpx #100           ; 2
    bne @copy          ; 3 taken / 2 last

; ---- verify dst against src + 16-bit checksum ----
    lda #0
    sta sum_lo
    sta sum_hi
    ldx #0
@check:
    lda dst_buf,x      ; 4
    cmp src_data,x     ; 4
    bne @fail          ; 2 not taken
    clc                ; 2
    adc sum_lo         ; 3
    sta sum_lo         ; 3
    lda sum_hi         ; 3
    adc #0             ; 2  propagate carry into high byte
    sta sum_hi         ; 3
    inx                ; 2
    cpx #100           ; 2
    bne @check         ; 3 taken / 2 last

    lda #<msg_ok
    ldx #>msg_ok
    jsr print_str
    jsr print_checksum
    jsr print_nl
    lda #0
    rts

@fail:
    lda #<msg_fail
    ldx #>msg_fail
    jsr print_str
    jsr print_checksum
    jsr print_nl
    lda #0
    rts

; print_checksum: print the 16-bit checksum as 4 hex digits
print_checksum:
    lda sum_hi
    jsr print_hex8
    lda sum_lo
    jmp print_hex8
