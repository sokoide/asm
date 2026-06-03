; macOS x86_64 (64-bit) Hello World
;   nasm -f macho64 hello.asm -o hello.o
;   ld -e _main -arch x86_64 -lSystem hello.o -o hello

global _main

section .text

_main:
    ; write(1, msg, len)
    mov     rax, 0x2000004      ; SYS_write = 4 | 0x20000000 (BSD class)
    mov     rdi, 1              ; fd = stdout
    lea     rsi, [rel msg]      ; buf (RIP-relative)
    mov     rdx, len            ; count
    syscall

    ; exit(0)
    mov     rax, 0x2000001      ; SYS_exit
    xor     rdi, rdi            ; exit code 0
    syscall

section .data
msg:    db "Hello World!", 10
len:    equ $ - msg
