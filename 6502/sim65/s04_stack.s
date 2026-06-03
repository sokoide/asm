; s04_stack.s - Scenario 4: Stack Operations
; =========================================
; Learning objectives:
;   - Stack page: $0100-$01FF (fixed 256 bytes, grows downward)
;   - PHA / PLA — push/pull accumulator
;   - TXS / TSX — set/check stack pointer
;   - Register save/restore pattern (PHA -> work -> PLA)

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
sp_before: .res 1
sp_after:  .res 1
val1:      .res 1
val2:      .res 1

; ---- Read-only data ----
.segment "RODATA"
msg_sp1:   .asciiz "SP: $01"
msg_sp2:   .asciiz " -> $01"
msg_lifo1: .asciiz "LIFO: pull #1=$"
msg_lifo2: .asciiz " pull #2=$"
msg_save:  .asciiz "Save/restore: push $42 -> overwrite -> pull=$"

; ---- Code ----
.segment "CODE"
_main:
    ; ---- Demo 1: Stack pointer movement ----
    tsx
    stx sp_before

    lda #$AA
    pha             ; push $AA
    lda #$CC
    pha             ; push $CC

    tsx
    stx sp_after

    ; Print "SP: $01XX -> $01YY"
    jsr print_msg_sp1
    lda sp_before
    jsr print_hex8

    jsr print_msg_sp2
    lda sp_after
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 2: LIFO order ----
    pla             ; pull $CC (last pushed)
    sta val1
    pla             ; pull $AA (first pushed)
    sta val2

    ; Print "LIFO: pull #1=$CC pull #2=$AA"
    jsr print_msg_lifo1
    lda val1
    jsr print_hex8

    jsr print_msg_lifo2
    lda val2
    jsr print_hex8
    jsr print_nl

    ; ---- Demo 3: Save/restore ----
    lda #$42
    pha             ; save $42
    lda #$FF        ; overwrite A
    pla             ; restore -> $42
    sta val1        ; Save result

    jsr print_msg_save
    lda val1
    jsr print_hex8
    jsr print_nl

    lda #0
    rts

; ---- Individual string print functions ----
print_msg_sp1:
    lda #'S'
    jsr _putchar
    lda #'P'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'1'
    jsr _putchar
    rts

print_msg_sp2:
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'>'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'0'
    jsr _putchar
    lda #'1'
    jsr _putchar
    rts

print_msg_lifo1:
    lda #'L'
    jsr _putchar
    lda #'I'
    jsr _putchar
    lda #'F'
    jsr _putchar
    lda #'O'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'#'
    jsr _putchar
    lda #'1'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_lifo2:
    lda #' '
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'#'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

print_msg_save:
    lda #'S'
    jsr _putchar
    lda #'a'
    jsr _putchar
    lda #'v'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'/'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'s'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #':'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'s'
    jsr _putchar
    lda #'h'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'$'
    jsr _putchar
    lda #'4'
    jsr _putchar
    lda #'2'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'>'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'o'
    jsr _putchar
    lda #'v'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'w'
    jsr _putchar
    lda #'r'
    jsr _putchar
    lda #'i'
    jsr _putchar
    lda #'t'
    jsr _putchar
    lda #'e'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'-'
    jsr _putchar
    lda #'>'
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #'p'
    jsr _putchar
    lda #'u'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #'l'
    jsr _putchar
    lda #'='
    jsr _putchar
    lda #'$'
    jsr _putchar
    rts

; ---- Shared helper subroutines ----

; ---- print newline ----
print_nl:
    lda #$0A
    jsr _putchar
    rts

; ---- print A as 2-digit hex ----
print_hex8:
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    jsr print_nibble
    pla
    and #$0F
    jsr print_nibble
    rts

print_nibble:
    cmp #10
    bcc @digit
    clc
    adc #'A' - '0' - 10
@digit:
    clc
    adc #'0'
@done:
    jsr _putchar
    rts
