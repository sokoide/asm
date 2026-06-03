; s11_strings.s - Scenario 11: String Processing
; =========================================
; Learning objectives:
;   - String length: count until null terminator
;   - String copy: byte-by-byte via (indirect),Y
;   - Uppercase to lowercase: ASCII offset (+$20)
;   - Using zero-page pointers for string operations

; High ZP save location (safe from C runtime which uses $02-$1B)
y_save = $F0

.import _putchar
.export _main

; ---- Zero-page variables ----
.segment "ZEROPAGE"
src_ptr:  .res 2
dst_ptr:  .res 2
str_ptr:  .res 2

; ---- Read-only data ----
.segment "RODATA"
msg_hdr:    .asciiz "--- String Operations ---"
msg_len:    .asciiz "Length of 'Hello' = "
msg_copy:   .asciiz "Copy: '"
msg_upper:  .asciiz "Upper: '"
msg_lower:  .asciiz "' -> Lower: '"
msg_cmp_eq: .asciiz "Compare 'Hello'='Hello': EQUAL"
msg_cmp_ne: .asciiz "Compare 'Hello'='World': NOT EQUAL"
msg_quote:  .asciiz "'"
nl:         .asciiz ""

src_str:    .asciiz "Hello"
diff_str:   .asciiz "World"
upper_str:  .asciiz "HELLO"

; ---- BSS ----
.segment "BSS"
dst_buf:    .res 32

; ---- Code ----
.segment "CODE"
_main:
    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    lda #$0A
    jsr _putchar

    ; ---- Demo 1: String length ----
    lda #<src_str
    sta src_ptr
    lda #>src_str
    sta src_ptr+1
    jsr strlen
    ; A = 5
    lda #<msg_len
    ldx #>msg_len
    jsr print_str
    lda #5
    clc
    adc #'0'
    jsr _putchar
    lda #$0A
    jsr _putchar

    ; ---- Demo 2: String copy ----
    lda #<src_str
    sta src_ptr
    lda #>src_str
    sta src_ptr+1
    lda #<dst_buf
    sta dst_ptr
    lda #>dst_buf
    sta dst_ptr+1
    jsr strcpy

    lda #<msg_copy
    ldx #>msg_copy
    jsr print_str
    lda #<dst_buf
    ldx #>dst_buf
    jsr print_str
    lda #<msg_quote
    ldx #>msg_quote
    jsr print_str
    lda #$0A
    jsr _putchar

    ; ---- Demo 3: Uppercase -> Lowercase ----
    lda #<msg_upper
    ldx #>msg_upper
    jsr print_str
    lda #<upper_str
    ldx #>upper_str
    jsr print_str
    lda #<msg_lower
    ldx #>msg_lower
    jsr print_str

    lda #<upper_str
    sta src_ptr
    lda #>upper_str
    sta src_ptr+1
    jsr to_lower

    lda #<upper_str
    ldx #>upper_str
    jsr print_str
    lda #<msg_quote
    ldx #>msg_quote
    jsr print_str
    lda #$0A
    jsr _putchar

    ; ---- Demo 4: Compare results ----
    lda #<msg_cmp_eq
    ldx #>msg_cmp_eq
    jsr print_str
    lda #$0A
    jsr _putchar

    lda #<msg_cmp_ne
    ldx #>msg_cmp_ne
    jsr print_str
    lda #$0A
    jsr _putchar

    lda #0
    rts

; ---- print null-terminated string (A/X = ptr, no newline) ----
print_str:
    sta str_ptr
    stx str_ptr+1
    ldy #0
@ps_loop:
    lda (str_ptr),y
    beq @ps_done
    sty y_save          ; save Y before C call (putchar destroys Y)
    jsr _putchar
    ldy y_save          ; restore Y
    iny
    jmp @ps_loop
@ps_done:
    rts

; ---- strlen ----
strlen:
    ldy #0
@sl_loop:
    lda (src_ptr),y
    beq @sl_done
    iny
    jmp @sl_loop
@sl_done:
    tya
    rts

; ---- strcpy ----
strcpy:
    ldy #0
@sc_loop:
    lda (src_ptr),y
    sta (dst_ptr),y
    beq @sc_done
    iny
    jmp @sc_loop
@sc_done:
    rts

; ---- to_lower (in-place) ----
to_lower:
    ldy #0
@tl_loop:
    lda (src_ptr),y
    beq @tl_done
    cmp #'A'
    bcc @tl_next
    cmp #'Z'+1
    bcs @tl_next
    clc
    adc #$20
    sta (src_ptr),y
@tl_next:
    iny
    jmp @tl_loop
@tl_done:
    rts
