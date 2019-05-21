global _main

section .text

_main:
    ; args passed on stack from last to first
    ; syscall)
    ; https://github.com/opensource-apple/xnu/blob/master/bsd/kern/syscalls.master
    ; 1	AUE_EXIT	ALL	{ void exit(int rval) NO_SYSCALL_STUB; } 
    ; 4	AUE_NULL	ALL	{ user_ssize_t write(int fd, user_addr_t cbuf, user_size_t nbyte); } 
    push  dword hello_world.len ; nbyte
    push  dword hello_world     ; cbuf
    push  dword 1               ; fd=1=stdout

    mov   eax, 4    ; 'write' syscall number 4
    sub   esp, 4    ; stack must be 16 byte aligned (3 pushed dwords=12 bytes, needs 4 more bytes)
    int   0x80      ; syscall
    add   esp, 16   ; reset stack


    push  dword 0   ; exit code 0
    mov   eax, 1    ; 'exit' syscall number 1
    sub   esp, 4    ; align stack, but why 12 fails (16 byte align)?
    int   0x80      ; syscall

section .data

hello_world: db "Hello World!", 10
.len: equ $ - hello_world
