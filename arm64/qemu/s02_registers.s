// s02_registers.s - Scenario 2: Registers and Arithmetic
// =======================================================
// Learning objectives:
//   - MOV/MOVZ for loading immediate values
//   - ADD/SUB for arithmetic operations
//   - INC using ADD #1, DEC using SUB #1
//   - Hexadecimal output subroutine
//   - 64-bit register handling

.section .text
.global _start

_start:
    // Set up stack pointer
    movz    x0, #0x4800, lsl #16
    mov     sp, x0

    // Test 1: MOV instruction
    ldr     x0, =msg1_mov
    bl      print_str

    mov     x0, #0x1234
    bl      print_hex64

    ldr     x0, =newline
    bl      print_str

    // Test 2: ADD (10 + 20)
    ldr     x0, =msg2_add
    bl      print_str

    mov     x0, #10
    mov     x1, #20
    add     x2, x0, x1          // x2 = 10 + 20 = 30
    mov     x0, x2
    bl      print_hex64

    ldr     x0, =newline
    bl      print_str

    // Test 3: SUB (30 - 5)
    ldr     x0, =msg3_sub
    bl      print_str

    mov     x0, #30
    mov     x1, #5
    sub     x2, x0, x1           // x2 = 30 - 5 = 25
    mov     x0, x2
    bl      print_hex64

    ldr     x0, =newline
    bl      print_str

    // Test 4: INC (ADD #1)
    ldr     x0, =msg4_inc
    bl      print_str

    mov     x0, #99
    add     x0, x0, #1           // x0 = 99 + 1 = 100
    bl      print_hex64

    ldr     x0, =newline
    bl      print_str

    // Test 5: DEC (SUB #1)
    ldr     x0, =msg5_dec
    bl      print_str

    mov     x0, #51
    sub     x0, x0, #1           // x0 = 51 - 1 = 50
    bl      print_hex64

    ldr     x0, =newline
    bl      print_str

    // Exit via semihosting
    mov     x0, #0x18
    ldr     x1, =0x20026
    hlt     #0xF000

// ---- Subroutines ----

// print_str: print null-terminated string at x0
print_str:
    stp     x29, x30, [sp, #-16]!   // Save frame pointer and LR
    mov     x29, sp                  // Set frame pointer (optional but conventional)
    mov     x4, x0
.loop:
    ldrb    w5, [x4]
    cbz     w5, .ret
    mov     w0, w5
    bl      uart_putc
    add     x4, x4, #1
    b       .loop
.ret:
    ldp     x29, x30, [sp], #16     // Restore frame pointer and LR
    ret

// uart_putc: write character in w0 to UART0
uart_putc:
    movz    x8, #0x0900, lsl #16    // x8 = 0x09000000 (UART0 base)
.wait:
    ldr     w9, [x8, #0x18]         // read UARTFR
    tbnz    w9, #5, .wait           // bit 5 = TXFF, wait if full
    strb    w0, [x8]                // write byte to UARTDR
    ret

// print_hex64: print 64-bit value in x0 as hexadecimal
// Preserves: x1-x7
print_hex64:
    stp     x29, x30, [sp, #-16]!   // Save frame pointer and LR
    mov     x29, sp                  // Set frame pointer (optional but conventional)
    mov     x1, x0                  // save value
    mov     x2, #60                 // start from bit 60
.hex_loop:
    // Extract nibble (4 bits)
    lsr     x3, x1, x2              // logical shift right
    and     x3, x3, #0xF            // mask lower 4 bits

    // Convert to ASCII
    cmp     x3, #10
    b.lo    .hex_digit
    add     x3, x3, #('A' - 10)     // A-F
    b       .hex_print
.hex_digit:
    add     x3, x3, #'0'            // 0-9
.hex_print:
    mov     w0, w3
    bl      uart_putc

    // Move to next nibble
    subs    x2, x2, #4
    b.pl    .hex_loop               // if x2 >= 0, continue

    ldp     x29, x30, [sp], #16     // Restore frame pointer and LR
    ret

// ---- Data ----
msg1_mov:
    .asciz "mov x0, #0x1234   -> X0="
msg2_add:
    .asciz "10 + 20           = 0x"
msg3_sub:
    .asciz "30 - 5            = 0x"
msg4_inc:
    .asciz "INC(99)          = 0x"
msg5_dec:
    .asciz "DEC(51)          = 0x"
newline:
    .asciz "\n"
