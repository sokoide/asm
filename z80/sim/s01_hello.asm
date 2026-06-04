; s01_hello.asm - Scenario 1: Hello World
; ========================================
; Learning objectives:
;   - Z80/CP/M program structure (ORG 0x0100)
;   - BDOS console output (function 9)
;   - LD, CALL, RET instructions

org 0x0100

_start:
    ld      c, 9              ; BDOS fn 9: print string
    ld      de, msg
    call    0x0005
    ret                       ; return to CP/M

; ---- Data ----
msg:
    defm    "Hello, Z80 World!\r\n$"
