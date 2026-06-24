; s14_psp.asm - Scenario 14: PSP and Command Line
; ==================================================
; Learning objectives:
;   - Program Segment Prefix (PSP): 256-byte block at program start
;   - DS/ES point to PSP at entry (before we change DS)
;   - PSP offset 80h: command tail length byte
;   - PSP offset 81h-FFh: command tail characters
;   - Saving PSP segment before modifying DS
;   - Environment block (PSP offset 2Ch)
; Difficulty: ★★★★★
;
; Usage: S14_PSP.EXE some arguments here
;        The program will display the command tail.

segment .text
global start

start:
    ; At entry, DS = ES = PSP segment.
    ; .data 変数は PSP とは別セグメントにあるため、DS を .data に切り替える前に
    ; PSP セグメント値をレジスタ(AX)に退避しておかないと、[psp_seg] への書き込みが
    ; PSP セグメント側のオフセットに飛んでしまい後から読み出せなくなる。
    mov ax, ds              ; AX = PSP segment(エントリ時の DS)

    ; Set DS/ES to our data segment
    mov bx, seg msg1
    mov ds, bx
    mov es, bx
    mov [psp_seg], ax       ; ここで初めて .data の変数に PSP を保存

    ; --- 1. Show PSP segment ---
    mov si, msg_psp
    call print_str
    mov ax, [psp_seg]
    call print_hex16
    call print_crlf

    ; --- 2. Read and display command tail ---
    ; Command tail is at PSP:80h
    ; Byte at 80h = length of tail
    ; Bytes 81h+ = the tail (space + arguments)
    mov si, msg_tail
    call print_str

    ; Set DS temporarily to PSP segment
    mov ax, [psp_seg]
    mov ds, ax

    mov cl, [0080h]         ; command tail length
    xor ch, ch

    ; Restore DS to data segment
    mov ax, seg msg1
    mov ds, ax

    ; Print length
    mov al, cl
    xor ah, ah
    call print_hex8
    mov si, msg_tail2
    call print_str

    ; Print the tail itself
    cmp cx, 0
    je  .no_tail

    ; Read from PSP:81h
    push ds
    mov ax, [psp_seg]
    mov ds, ax
    mov si, 0081h           ; PSP offset 81h
.print_tail:
    lodsb
    mov dl, al
    mov ah, 02h
    int 21h
    loop .print_tail
    pop ds

    call print_crlf
    jmp .show_env

.no_tail:
    mov si, msg_empty
    call print_str

    ; --- 3. Show environment segment ---
.show_env:
    mov si, msg_env
    call print_str

    ; Environment segment is at PSP:2Ch
    push ds
    mov ax, [psp_seg]
    mov ds, ax
    mov ax, [002Ch]         ; environment segment
    pop ds
    mov [env_seg], ax
    call print_hex16
    call print_crlf

    ; Print first few bytes of environment
    mov si, msg_env_contents
    call print_str

    push ds
    mov ax, [env_seg]
    mov ds, ax
    xor si, si
    mov cx, 40              ; show first 40 bytes
.print_env:
    lodsb
    cmp al, 0
    je  .env_null
    mov dl, al
    jmp .env_print
.env_null:
    mov dl, '|'             ; show null as | separator
.env_print:
    mov ah, 02h
    int 21h
    loop .print_env
    pop ds

    call print_crlf
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

print_hex16:
    push ax
    mov al, ah
    call print_hex8
    pop ax
print_hex8:
    push ax
    push cx
    mov cl, 4
    shr al, cl
    call print_nibble
    pop cx
    pop ax
print_nibble:
    and al, 0Fh
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    mov dl, al
    mov ah, 02h
    int 21h
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

msg1:           db "PSP & Command Line:", 13, 10, 0
msg_psp:        db "  PSP segment:     0x", 0
msg_tail:       db "  Tail length:     0x", 0
msg_tail2:      db 13, 10, "  Command tail:    ", 0
msg_empty:      db "(empty - try: S14_PSP.EXE hello world)", 13, 10, 0
msg_env:        db "  Env segment:     0x", 0
msg_env_contents db "  First 40 bytes:  ", 0
msg_done:       db "Done!", 13, 10, 0

psp_seg  dw 0                 ; saved PSP segment
env_seg  dw 0                 ; environment segment

segment .stack stack
    resb 200h
