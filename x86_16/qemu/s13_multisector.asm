; s13_multisector.asm - Scenario 13: Multi-Sector Disk Loading
; ==============================================================
; Learning objectives:
;   - INT 0x13 AH=02h: read sectors from disk into memory
;   - CHS addressing (Cylinder, Head, Sector)
;   - Loading code beyond the 512-byte boot sector
;   - Jumping to code loaded from sector 2
;
; Structure:
;   Sector 1 (this file, bytes 0-511): boot sector, loads sector 2
;   Sector 2 (bytes 512-1023): additional code loaded at 0x7E00
;
; Build: nasm -f bin -o s13_multisector.bin s13_multisector.asm
;   (flat binary, no linker needed — ORG sets base address)

bits 16
org 0x7C00

; ============================================================
; SECTOR 1: Boot sector (loaded by BIOS at 0x7C00)
; ============================================================

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Print status message ---
    mov si, msg_loading
    call print_str

    ; --- Read sector 2 using INT 0x13 AH=02h ---
    ; Parameters:
    ;   AH = 02h (read sectors)
    ;   AL = number of sectors to read (1)
    ;   CH = cylinder (0)
    ;   CL = sector number, 1-based (2 = second sector)
    ;   DH = head (0)
    ;   DL = drive (0x00 = first floppy)
    ;   ES:BX = destination buffer (0x0000:0x7E00)
    ;
    ; Note: sectors are numbered starting from 1 (not 0)
    ;       0x7E00 is right after the boot sector (0x7C00 + 512)
    mov ah, 0x02
    mov al, 1               ; Read 1 sector
    mov ch, 0               ; Cylinder 0
    mov cl, 2               ; Sector 2
    mov dh, 0               ; Head 0
    mov dl, 0x00            ; Drive 0 (floppy)
    mov bx, 0x7E00          ; Buffer at ES:BX
    int 0x13
    jc  .disk_error         ; CF=1 on error

    ; Success — jump to sector 2 code at 0x7E00
    mov si, msg_ok
    call print_str
    jmp 0x7E00              ; Far jump to loaded code

.disk_error:
    ; AH = error code, AL = sectors actually read
    mov si, msg_err
    call print_str
    mov al, ah
    call print_hex8
    call print_crlf

.halt:
    cli
    hlt
    jmp .halt

; ---- 16-bit subroutines ----

print_str:
    lodsb
    or  al, al
    jz  .ret
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp print_str
.ret:
    ret

print_hex8:
    push ax
    mov cl, 4
    shr al, cl
    call print_nibble
    pop ax
print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .out
    add al, 7
.out:
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    ret

print_crlf:
    mov ax, 0x0E0D
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; ---- Data ----
msg_loading db "Loading sector 2...", 13, 10, 0
msg_ok      db "OK! Jumping to 0x7E00", 13, 10, 0
msg_err     db "Disk error! Code=0x", 0

; Pad sector 1 to 510 bytes + boot signature
times 510-($-$$) db 0
dw 0xAA55

; ============================================================
; SECTOR 2: Loaded at 0x7E00 by our INT 0x13 call
; ============================================================
; Since we use ORG 0x7C00, addresses here are automatically
; correct: sector2_start = 0x7C00 + 512 = 0x7E00

sector2:
    ; We can call print_str from sector 1 (it's still in memory)
    mov si, s2_welcome
    call print_str

    mov si, s2_info1
    call print_str

    mov si, s2_info2
    call print_str

    ; Display current stack pointer
    mov si, s2_sp
    call print_str
    mov ax, sp
    call print_hex16_s2
    call print_crlf

    mov si, s2_done
    call print_str

.halt2:
    cli
    hlt
    jmp .halt2

; Small local hex printer (reuses BIOS, avoids cross-sector issues)
print_hex16_s2:
    push ax
    mov al, ah
    call print_hex8
    pop ax
    jmp print_hex8          ; tail call for low byte

; ---- Sector 2 Data ----
s2_welcome db 13, 10, "=== Sector 2 loaded! ===", 13, 10, 0
s2_info1   db "This code was read from disk", 13, 10, 0
s2_info2   db "by INT 0x13 AH=02h.", 13, 10, 0
s2_sp      db "SP=0x", 0
s2_done    db 13, 10, "Multi-sector loading works!", 0

; Pad to exactly 1024 bytes (2 sectors total)
times 1024-($-$$) db 0
