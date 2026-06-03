; s13_fileio.asm - Scenario 13: File I/O
; =========================================
; Learning objectives:
;   - INT 21h AH=3Ch: create file (CX = attributes)
;   - INT 21h AH=40h: write to file (BX = handle)
;   - INT 21h AH=3Dh: open file (AL = access mode)
;   - INT 21h AH=3Fh: read from file (BX = handle)
;   - INT 21h AH=3Eh: close file (BX = handle)
;   - DOS file handle management
;   - Error checking with carry flag
; Difficulty: ★★★★★

segment .text

start:
    mov ax, seg msg1
    mov ds, ax
    mov es, ax

    ; --- 1. Create a file ---
    mov si, msg_create
    call print_str

    mov ah, 3Ch             ; DOS: create file
    mov cx, 0               ; normal attributes
    mov dx, filename
    int 21h
    jc  .create_error       ; carry flag set on error

    mov [handle], ax        ; save file handle
    mov si, msg_ok
    call print_str
    jmp .write_file

.create_error:
    mov si, msg_fail
    call print_str
    jmp .done

    ; --- 2. Write to file ---
.write_file:
    mov si, msg_write
    call print_str

    mov ah, 40h             ; DOS: write to file
    mov bx, [handle]        ; file handle
    mov cx, msg_out_len     ; number of bytes to write
    mov dx, msg_out         ; data to write
    int 21h
    jc  .write_error

    mov si, msg_ok
    call print_str
    jmp .close_file

.write_error:
    mov si, msg_fail
    call print_str
    jmp .done

    ; --- 3. Close file ---
.close_file:
    mov ah, 3Eh             ; DOS: close file
    mov bx, [handle]
    int 21h

    ; --- 4. Open file for reading ---
    mov si, msg_open
    call print_str

    mov ah, 3Dh             ; DOS: open file
    mov al, 0               ; read-only mode
    mov dx, filename
    int 21h
    jc  .open_error

    mov [handle], ax
    mov si, msg_ok
    call print_str
    jmp .read_file

.open_error:
    mov si, msg_fail
    call print_str
    jmp .done

    ; --- 5. Read from file ---
.read_file:
    mov si, msg_read
    call print_str

    mov ah, 3Fh             ; DOS: read from file
    mov bx, [handle]
    mov cx, 255             ; max bytes to read
    mov dx, readbuf
    int 21h
    jc  .read_error

    ; AX = bytes actually read
    mov cx, ax
    mov si, readbuf
    push cx
.print_read:
    lodsb
    mov dl, al
    mov ah, 02h
    int 21h
    loop .print_read
    pop cx

    call print_crlf

    ; Null-terminate and show as string
    mov bx, cx
    mov byte [readbuf+bx], 0

    ; Close the file
    mov ah, 3Eh
    mov bx, [handle]
    int 21h
    jmp .done

.read_error:
    mov si, msg_fail
    call print_str

.done:
    mov si, msg_done
    call print_str
    mov ax, 4C00h
    int 21h

; ---- Subroutines ----

print_str:
    lodsb
    or  al, al
    jz  .done
    mov dl, al
    mov ah, 02h
    int 21h
    jmp print_str
.done:
    ret

print_crlf:
    mov dl, 13
    mov ah, 02h
    int 21h
    mov dl, 10
    mov ah, 02h
    int 21h
    ret

segment .data

msg1:       db "File I/O demo:", 13, 10, 0
msg_create: db "  Creating file... ", 0
msg_write:  db "  Writing data...  ", 0
msg_open:   db "  Opening file...  ", 0
msg_read:   db "  Reading: ", 0
msg_ok:     db "OK", 13, 10, 0
msg_fail:   db "FAILED", 13, 10, 0
msg_done:   db "Done!", 13, 10, 0

filename db "test.txt", 0
msg_out  db "Hello from 8086!", 13, 10
msg_out_len equ $ - msg_out

handle  dw 0                    ; file handle storage
readbuf times 256 db 0          ; read buffer

segment .stack stack
    resb 200h
