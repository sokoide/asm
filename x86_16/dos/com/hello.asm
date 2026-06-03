; hello.asm - 8086 .COM
org 0x100

start:
    mov ah, 09h         ; DOS func 09h (display string)
    lea dx, message     ; address of the message
    int 21h             ; DOS interrupt

    mov ah, 4ch         ; DOS func 4Ch (exit)
    int 21h             ; DOS interrupt

message db "Hello, COM world!$"

