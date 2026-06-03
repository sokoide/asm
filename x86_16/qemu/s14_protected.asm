; s14_protected.asm - Scenario 14: 32-bit Protected Mode
; =======================================================
; Learning objectives:
;   - Global Descriptor Table (GDT) structure and purpose
;   - LGDT instruction: load GDT register
;   - CR0 register: PE bit enables protected mode
;   - Far jump to flush pipeline after mode switch
;   - Segment selectors (index into GDT)
;   - 32-bit registers: EAX, ESI, EDI, ESP
;   - Linear address mapping: VRAM at 0x000B8000
;   - Flat memory model: base=0, limit=4GB
;
; Structure:
;   Sector 1: 16-bit boot + GDT + mode switch
;   Sector 2: 32-bit protected mode code

bits 16
org 0x7C00

; ============================================================
; SECTOR 1: Boot → Protected Mode transition
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

    ; --- Print status (last BIOS call before PM) ---
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
    ;   pm_entry is in sector 2 at ~0x7E00
    jmp 0x08:pm_entry

.error:
    mov si, msg_err
    call print_str_16
    cli
    hlt

; ---- 16-bit print subroutine ----
print_str_16:
    lodsb
    or  al, al
    jz  .ret
    mov ah, 0x0E
    xor bh, bh
    int 0x10
    jmp print_str_16
.ret:
    ret

msg_switching db "Switching to PM...", 13, 10, 0
msg_err       db "Disk read error!", 0

; ============================================================
; GDT (Global Descriptor Table)
; ============================================================
; Each entry is 8 bytes:
;   [Limit low 16][Base low 16][Base mid 8][Access][Flags+Limit hi 4][Base hi 8]
;
; Access byte: [Present(1)][DPL(2)][S(1)][Type(4)]
;   S=1 for code/data, Type: code=1010(A), data=0010(2)
; Flags: [Granularity(1)][D/B(1)][0][0]
;   G=1: limit in 4KB pages, D=1: 32-bit

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

    ; Step 5: Set up data segment registers with data selector
    mov ax, 0x10             ; Data segment selector (GDT index 2)
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000         ; Stack in safe memory

    ; Step 6: Write directly to VRAM
    ; In protected mode with flat model (base=0),
    ; VRAM linear address = 0x000B8000
    ; (In real mode it was segment 0xB800, offset = 0xB800 * 16 = 0xB8000)

    ; --- Draw colored header (row 0) ---
    ; Each character: [ASCII byte][attribute byte]
    ; Attribute: [Blink][BG RGB][Bright][FG RGB]
    mov esi, pm_header
    mov edi, 0x000B8000      ; VRAM row 0
    mov ah, 0x4F             ; White on red
.call_header:
    lodsb                    ; AL = [ESI], ESI++
    or  al, al
    jz  .fill_header
    stosw                    ; [EDI] = AX, EDI += 2
    jmp .call_header
.fill_header:
    mov al, ' '
    mov ecx, edi
    shr ecx, 1
    neg ecx
    add ecx, 80
    rep stosw

    ; --- Draw separator (row 1) ---
    mov edi, 0x000B8000 + 160
    mov eax, 0x1F2D001F     ; Two chars at once: white-on-blue '-'
    ; Actually stosw writes 16 bits, let's do it simply
    mov ax, 0x1F2D           ; White on blue, '-'
    mov ecx, 80
    rep stosw

    ; --- Print message (row 3) ---
    mov esi, pm_msg1
    mov edi, 0x000B8000 + (80 * 2 * 3)  ; Row 3
    mov ah, 0x0A             ; Light green on black
.print1:
    lodsb
    or  al, al
    jz  .msg2
    stosw
    jmp .print1

.msg2:
    mov esi, pm_msg2
    mov edi, 0x000B8000 + (80 * 2 * 4)  ; Row 4
    mov ah, 0x0E             ; Yellow on black
.print2:
    lodsb
    or  al, al
    jz  .msg3
    stosw
    jmp .print2

.msg3:
    mov esi, pm_msg3
    mov edi, 0x000B8000 + (80 * 2 * 5)  ; Row 5
    mov ah, 0x0B             ; Light cyan on black
.print3:
    lodsb
    or  al, al
    jz  .done
    stosw
    jmp .print3

.done:
    hlt
    jmp .done

; ---- Sector 2 Data ----
pm_header db " 32-bit Protected Mode Active ", 0
pm_msg1   db "CR0.PE = 1: protected mode enabled", 0
pm_msg2   db "GDT: flat model (base=0, limit=4GB)", 0
pm_msg3   db "VRAM at linear 0x000B8000 (no BIOS needed)", 0

; Pad to 1024 bytes (2 sectors total)
times 1024-($-$$) db 0
