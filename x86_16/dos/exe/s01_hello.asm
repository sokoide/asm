; s01_hello.asm - Scenario 1: Hello World
; =========================================
; Learning objectives:
;   - DOS .EXE structure (segment directives)
;   - Segment register initialization (DS for data access)
;   - DOS INT 21h AH=09h ($-terminated string output)
;   - DOS INT 21h AH=4Ch (program termination with return code)
;   - Stack segment declaration
; Difficulty: ★☆☆☆☆

segment .text

start:
    ; Set DS to the data segment — required before accessing any data
    mov ax, seg message
    mov ds, ax

    ; Display $-terminated string via DOS
    mov ah, 09h             ; DOS function: print string
    mov dx, message         ; DS:DX -> $-terminated string
    int 21h                 ; call DOS

    ; Exit to DOS
    mov ax, 4C00h           ; AH=4Ch (terminate), AL=00h (return code 0)
    int 21h

segment .data

message db "Hello, DOS World!", 13, 10, "$"

segment .stack stack
    resb 100h               ; 256-byte stack
