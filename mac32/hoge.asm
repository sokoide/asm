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

    ; http://takesako.hatenablog.com/entry/20090313/1236937017
    ;  dummy 4byte push for return address.
    ; because syscall is generally called by 'call' but we call it by int 0x80.
    ; if you want to use 'call', it'll be as below.
    ;
    ;kernel:
    ; 	int	80h	; Call kernel
    ; 	ret

    ; open:
    ; 	push	dword mode
    ; 	push	dword flags
    ; 	push	dword path
    ; 	mov	eax, 5
    ; 	call	kernel
    ; 	add	esp, byte 12
    ; 	ret
    ;
    sub   esp, 4    ;
    int   0x80      ; syscall
    add   esp, 16   ; reset stack


    push  dword 0   ; exit code 0
    mov   eax, 1    ; 'exit' syscall number 1
    sub   esp, 4    ; dummy 4byte push
    int   0x80      ; syscall

section .data

hello_world: db "Hello World!", 10
.len: equ $ - hello_world
