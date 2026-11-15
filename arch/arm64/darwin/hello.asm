; macOS arm64 (AArch64) Hello World
;   clang -c -arch arm64 -x assembler hello.asm -o hello.o
;   ld -e _main -arch arm64 -lSystem hello.o -o hello

.globl  _main
.align  2

.text

_main:
    ; write(1, msg, len)
    mov     x0, #1              ; fd = stdout
    adrp    x1, msg@PAGE        ; buf (RIP-relative)
    add     x1, x1, msg@PAGEOFF
    mov     x2, len             ; count (文字列長、len = . - msg)
    mov     x16, #4             ; SYS_write
    svc     #0x80               ; BSD syscall

    ; exit(0)
    mov     x0, #0              ; exit code
    mov     x16, #1             ; SYS_exit
    svc     #0x80

.data
msg:    .ascii  "Hello World!\n"
len     =       . - msg
