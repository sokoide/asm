; macOS i386 (32-bit) Hello World
;   nasm -f macho32 hello.asm -o hello.o
;   ld -e _main -arch i386 -lSystem hello.o -o hello
; NOTE: macOS 10.14 以降は i386 バイナリが動作しません

global _main

section .text

_main:
    ; write(1, msg, len)
    push    dword len
    push    dword msg
    push    dword 1
    mov     eax, 4          ; SYS_write
    call    _syscall
    add     esp, 12         ; 引数をスタックから除去

    ; exit(0)
    push    dword 0
    mov     eax, 1          ; SYS_exit
    call    _syscall
    ; exit は戻らないのでスタックを戻す必要なし

; int 0x80 ラッパー:
; macOS の int 0x80 は call と違い戻りアドレスを自動で積まないため、
; ダミー領域を確保してから呼び出す。
_syscall:
    sub     esp, 4
    int     0x80
    add     esp, 4
    ret

section .data
msg:    db "Hello World!", 10
len:    equ $ - msg
