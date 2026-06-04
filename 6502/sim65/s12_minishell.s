; s12_minishell.s - Scenario 12: Interactive Mini Shell
; ========================================
; Learning objectives:
;   - _getchar / _putchar for character I/O
;   - Line editor with backspace handling
;   - Command parsing: string compare
;   - Menu dispatch pattern
;   - Integration of all previous concepts
; Commands: hello, count, hex, help, quit

y_save = $F0

.import print_str, print_nl, print_hex8
.import _putchar, _getchar
.export _main

.segment "ZEROPAGE"
input_buf:    .res 32
buf_idx:      .res 1
running:      .res 1
cmp_cmd:      .res 2

.segment "RODATA"
msg_welcome: .asciiz "6502 Mini Shell - type 'help'"
msg_prompt:  .asciiz "> "
msg_unknown: .asciiz "? Unknown command"
msg_hello:   .asciiz "Hello from 6502!"
msg_help:    .asciiz "Commands: hello count hex help quit"
msg_quit:    .asciiz "Goodbye!"
msg_count:   .asciiz "Count: "
msg_hex_hdr: .asciiz "Hex: "

cmd_hello: .asciiz "hello"
cmd_count: .asciiz "count"
cmd_hex:   .asciiz "hex"
cmd_help:  .asciiz "help"
cmd_quit:  .asciiz "quit"

.segment "CODE"
_main:
    lda #<msg_welcome
    ldx #>msg_welcome
    jsr print_str
    jsr print_nl

    lda #1
    sta running

main_loop:
    lda running
    beq main_exit

    lda #<msg_prompt
    ldx #>msg_prompt
    jsr print_str

    jsr read_line
    jsr dispatch

    jmp main_loop
main_exit:
    lda #0
    rts

; ---- Read line ----
read_line:
    lda #0
    sta buf_idx
    ldy #0
rl_loop:
    sty y_save
    jsr _getchar
    ldy y_save
    cmp #$0A
    beq rl_done
    cmp #$0D
    beq rl_done
    cmp #$7F
    beq rl_bs
    cmp #$08
    beq rl_bs
    cpy #30
    bcs rl_loop
    sta input_buf,y
    iny
    sty y_save
    jsr _putchar
    ldy y_save
    jmp rl_loop
rl_bs:
    cpy #0
    beq rl_loop
    dey
    sty y_save
    lda #$08
    jsr _putchar
    lda #' '
    jsr _putchar
    lda #$08
    jsr _putchar
    ldy y_save
    jmp rl_loop
rl_done:
    lda #0
    sta input_buf,y
    sty buf_idx
    lda #$0A
    jsr _putchar
    rts

; ---- Dispatch ----
dispatch:
    ; Check hello
    lda #<cmd_hello
    sta cmp_cmd
    lda #>cmd_hello
    sta cmp_cmd+1
    jsr streq_cmd
    beq @not_hello
    lda #<msg_hello
    ldx #>msg_hello
    jsr print_str
    jsr print_nl
    rts
@not_hello:

    ; Check count
    lda #<cmd_count
    sta cmp_cmd
    lda #>cmd_count
    sta cmp_cmd+1
    jsr streq_cmd
    beq @not_count
    jsr do_count
    rts
@not_count:

    ; Check hex
    lda #<cmd_hex
    sta cmp_cmd
    lda #>cmd_hex
    sta cmp_cmd+1
    jsr streq_cmd
    beq @not_hex
    jsr do_hex
    rts
@not_hex:

    ; Check help
    lda #<cmd_help
    sta cmp_cmd
    lda #>cmd_help
    sta cmp_cmd+1
    jsr streq_cmd
    beq @not_help
    lda #<msg_help
    ldx #>msg_help
    jsr print_str
    jsr print_nl
    rts
@not_help:

    ; Check quit
    lda #<cmd_quit
    sta cmp_cmd
    lda #>cmd_quit
    sta cmp_cmd+1
    jsr streq_cmd
    beq @not_quit
    lda #<msg_quit
    ldx #>msg_quit
    jsr print_str
    jsr print_nl
    lda #0
    sta running
    rts
@not_quit:

    lda #<msg_unknown
    ldx #>msg_unknown
    jsr print_str
    jsr print_nl
    rts

; ---- String compare input_buf vs cmp_cmd ----
streq_cmd:
    ldy #0
@se_loop:
    lda input_buf,y
    cmp (cmp_cmd),y
    bne @se_ne
    cmp #0
    beq @se_eq
    iny
    jmp @se_loop
@se_eq:
    lda #1
    rts
@se_ne:
    lda #0
    rts

; ---- Command: count ----
do_count:
    lda #<msg_count
    ldx #>msg_count
    jsr print_str
    lda #5
    sta y_save
@dc_loop:
    lda y_save
    clc
    adc #'0'
    jsr _putchar
    lda #' '
    jsr _putchar
    dec y_save
    bne @dc_loop
    jsr print_nl
    rts

; ---- Command: hex ----
do_hex:
    lda #<msg_hex_hdr
    ldx #>msg_hex_hdr
    jsr print_str
    lda #0
    sta y_save
@dh_loop:
    lda y_save
    jsr print_hex8
    lda #' '
    jsr _putchar
    inc y_save
    lda y_save
    cmp #16
    bne @dh_loop
    jsr print_nl
    rts
