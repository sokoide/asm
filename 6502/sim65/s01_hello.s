; s01_hello.s - Scenario 1: Hello World
; =========================================
; Learning objectives:
;   - Program structure (.import, .export, .segment)
;   - C runtime entry point (_main) and return (rts)
;   - String output via _puts
;   - 16-bit address split (LDA #<addr, LDX #>addr)
;   - Null-terminated string definition (.asciiz)

.import _puts
.export _main

.segment "RODATA"
message: .asciiz "Hello, 6502 World!"

.segment "CODE"
_main:
    lda #<message    ; アドレスの下位バイト
    ldx #>message    ; アドレスの上位バイト
    jsr _puts        ; puts(message) → stdout へ出力
    lda #0
    rts              ; return 0 → sim65 が終了
