; s14_protected.asm - Scenario 14: 32-bit Protected Mode
; =======================================================
; Learning objectives:
;   - Global Descriptor Table (GDT) structure and purpose
;   - LGDT instruction: load GDT register
;   - CR0 register: PE bit enables protected mode
;   - Far jump to flush pipeline after mode switch
;   - Segment selectors (index into GDT)
;   - 32-bit registers: EAX, ESI, EDI, ESP
;   - Flat memory model: base=0, limit=4GB
;   - I/O port access (IN/OUT) works in protected mode at CPL=0
;
; Structure:
;   Sector 1: 16-bit boot + GDT + mode switch
;   Sector 2: 32-bit protected mode code

bits 16
org 0x7C00

; ============================================================
; SECTOR 1: Boot -> Protected Mode transition
; ============================================================

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; --- Load sector 2 (contains 32-bit code) ---
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 2               ; Sector 2
    mov dh, 0
    mov dl, 0x00
    mov bx, 0x7E00          ; Load at 0x7E00
    int 0x13
    jc  .error

    ; --- Print status (last use of 16-bit uart_putc) ---
    mov si, msg_switching
    call print_str_16

    ; ===== Enter Protected Mode =====

    ; Step 1: Disable interrupts (NMI and hardware)
    cli

    ; Step 2: Load GDT register
    lgdt [gdt_descriptor]

    ; Step 3: Set PE (Protection Enable) bit in CR0
    mov eax, cr0
    or  eax, 1              ; Bit 0 = PE
    mov cr0, eax

    ; Step 4: Far jump to flush 16-bit prefetch queue
    ;   0x08 = code segment selector (GDT index 1, ring 0)
    jmp 0x08:pm_entry

.error:
    mov si, msg_err
    call print_str_16
    cli
    hlt

; ---- 16-bit UART subroutines ----

uart_putc_16:
    push    dx
    push    ax
    mov     dx, 0x3FD
.wait:
    in      al, dx
    test    al, 0x20
    jz      .wait
    mov     dx, 0x3F8
    pop     ax
    out     dx, al
    pop     dx
    ret

print_str_16:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc_16
    jmp print_str_16
.ret:
    ret

msg_switching db "Switching to PM...", 13, 10, 0
msg_err       db "Disk read error!", 0

; ============================================================
; GDT (Global Descriptor Table)
; ============================================================

gdt_start:
    ; --- Descriptor 0: Null (required by processor) ---
    dq 0

    ; --- Descriptor 1: Code segment (selector 0x08) ---
    ; Base=0x00000000, Limit=0xFFFFF (4GB with 4KB pages)
    ; 32-bit, executable, readable, ring 0
    dw 0xFFFF               ; Limit [15:0]
    dw 0x0000               ; Base [15:0]
    db 0x00                  ; Base [23:16]
    db 10011010b             ; Access: P=1 DPL=00 S=1 Type=1010
    db 11001111b             ; Flags: G=1 D=1, Limit[19:16]=0xF
    db 0x00                  ; Base [31:24]

    ; --- Descriptor 2: Data segment (selector 0x10) ---
    ; Base=0x00000000, Limit=0xFFFFF (4GB)
    ; 32-bit, writable, ring 0
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b             ; Access: P=1 DPL=00 S=1 Type=0010
    db 11001111b
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1   ; GDT size - 1
    dd gdt_start                  ; GDT linear address

; Pad sector 1
times 510-($-$$) db 0
dw 0xAA55

; ============================================================
; SECTOR 2: 32-bit Protected Mode Code (loaded at 0x7E00)
; ============================================================

bits 32

pm_entry:
    ; ===== Now in 32-bit Protected Mode =====
    ; BIOS interrupts are NO LONGER AVAILABLE
    ; But I/O ports (IN/OUT) still work at CPL=0

    ; Step 5: Set up data segment registers with data selector
    mov ax, 0x10             ; Data segment selector (GDT index 2)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000         ; Stack in safe memory

    ; Step 6: Print messages via COM1 serial (I/O port)
    ; In protected mode, OUT/IN instructions still work

    mov esi, pm_msg1
    call print_str_32
    mov esi, pm_msg2
    call print_str_32
    mov esi, pm_msg3
    call print_str_32
    mov esi, pm_msg4
    call print_str_32

.done:
    hlt
    jmp .done

; ---- 32-bit subroutines ----

; uart_putc_32: output character in AL to COM1
uart_putc_32:
    push    edx
    push    eax
    mov     dx, 0x3FD
.wait:
    in      al, dx
    test    al, 0x20
    jz      .wait
    mov     dx, 0x3F8
    pop     eax
    out     dx, al
    pop     edx
    ret

; print_str_32: print null-terminated string at ESI
print_str_32:
    lodsb
    or  al, al
    jz  .ret
    call uart_putc_32
    jmp print_str_32
.ret:
    ret

; ---- Sector 2 Data ----
pm_msg1 db "CR0.PE = 1: protected mode enabled", 13, 10, 0
pm_msg2 db "GDT: flat model (base=0, limit=4GB)", 13, 10, 0
pm_msg3 db "I/O ports (IN/OUT) work at CPL=0", 13, 10, 0
pm_msg4 db "32-bit protected mode active!", 13, 10, 0

; Pad to 1024 bytes (2 sectors total)
times 1024-($-$$) db 0
