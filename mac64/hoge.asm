global _main

section .text

_main:
    ; amd64abi args passed on rdi, rsi, rdx, r10, r8 and r9
    ; syscall)
    ; https://github.com/opensource-apple/xnu/blob/master/bsd/kern/syscalls.master
    ; 1	AUE_EXIT	ALL	{ void exit(int rval) NO_SYSCALL_STUB; } 
    ; 4	AUE_NULL	ALL	{ user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte); } 
    mov     rax, 0x2000004          ; 'write' syscall 4 + 0x20000000
    mov     rdi, 1                  ; fd=1=stdout
    mov     rsi, hello_world        ; cbuf
    mov     rdx, hello_world.len    ; nbyte
    syscall

    mov     rax, 0x2000001          ; 'exit' syscall 4 + 0x20000000
    mov     rdi, 0                  ; exit code 0
    syscall

section .data

hello_world: db "Hello World!", 10
.len: equ $ - hello_world
