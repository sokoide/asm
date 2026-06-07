// s12_minishell.s - Scenario 12: Interactive Mini Shell
// ========================================
// Learning objectives:
//   - Combining all previous concepts into one program
//   - Serial input and output (UART TX/RX)
//   - String comparison for command dispatch
//   - Building a read-eval-print loop (REPL)

.section .text
.global _start

_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // Print banner
    lis     %r3, msg_bn@ha; addi %r3, %r3, msg_bn@l; bl print_str
    lis     %r3, msg_h1@ha; addi %r3, %r3, msg_h1@l; bl print_str
    lis     %r3, msg_h2@ha; addi %r3, %r3, msg_h2@l; bl print_str
    lis     %r3, msg_h3@ha; addi %r3, %r3, msg_h3@l; bl print_str

    // Main loop: print prompt, read line, dispatch
.Lmain:
    lis     %r3, msg_pr@ha; addi %r3, %r3, msg_pr@l; bl print_str
    bl      read_line
    bl      print_crlf

    // Compare input with "hello"
    lis     %r3, input@ha; addi %r3, %r3, input@l
    lis     %r4, cmd_hello@ha; addi %r4, %r4, cmd_hello@l
    bl      strcmp
    beq     .Lhello

    // Compare input with "help"
    lis     %r3, input@ha; addi %r3, %r3, input@l
    lis     %r4, cmd_help@ha; addi %r4, %r4, cmd_help@l
    bl      strcmp
    beq     .Lhelp

    // Compare input with "quit"
    lis     %r3, input@ha; addi %r3, %r3, input@l
    lis     %r4, cmd_quit@ha; addi %r4, %r4, cmd_quit@l
    bl      strcmp
    beq     .Lquit

    // Empty line? (first char is null) -> just loop
    lis     %r3, input@ha; addi %r3, %r3, input@l
    lbz     %r3, 0(%r3)
    cmpwi   %r3, 0
    beq     .Lmain

    // Unknown command
    lis     %r3, msg_unk@ha; addi %r3, %r3, msg_unk@l; bl print_str
    b       .Lmain

.Lhello:
    lis     %r3, msg_hi@ha; addi %r3, %r3, msg_hi@l; bl print_str
    b       .Lmain

.Lhelp:
    lis     %r3, msg_h1@ha; addi %r3, %r3, msg_h1@l; bl print_str
    lis     %r3, msg_h2@ha; addi %r3, %r3, msg_h2@l; bl print_str
    lis     %r3, msg_h3@ha; addi %r3, %r3, msg_h3@l; bl print_str
    b       .Lmain

.Lquit:
    lis     %r3, msg_bye@ha; addi %r3, %r3, msg_bye@l; bl print_str

halt:   b       halt

// ---- Subroutines ----

// read_line: read chars into input buffer until Enter
read_line:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    stw     %r31, 12(%r1)
    lis     %r31, input@ha
    addi    %r31, %r31, input@l
    mr      %r4, %r31              // r4 = buffer pointer
.Lrl_loop:
    bl      uart_getc
    // Check for Enter (CR = 0x0D or LF = 0x0A)
    cmpwi   %r3, 0x0D
    beq     .Lrl_enter
    cmpwi   %r3, 0x0A
    beq     .Lrl_enter
    // Check for Backspace (0x08)
    cmpwi   %r3, 0x08
    beq     .Lrl_bs
    // Only store printable chars (>= 0x20)
    cmpwi   %r3, 0x20
    blt     .Lrl_loop
    // Check buffer limit
    subf    %r5, %r31, %r4          // r5 = current length
    cmpwi   %r5, 30
    bge     .Lrl_loop
    // Store and echo
    stb     %r3, 0(%r4)
    addi    %r4, %r4, 1
    bl      uart_putc
    b       .Lrl_loop
.Lrl_bs:
    subf    %r5, %r31, %r4          // current length
    cmpwi   %r5, 0
    beq     .Lrl_loop               // nothing to delete
    addi    %r4, %r4, -1
    // Erase character on terminal: BS + space + BS
    li      %r3, 0x08
    bl      uart_putc
    li      %r3, 0x20
    bl      uart_putc
    li      %r3, 0x08
    bl      uart_putc
    b       .Lrl_loop
.Lrl_enter:
    li      %r3, 0
    stb     %r3, 0(%r4)             // null terminate
    lwz     %r31, 12(%r1)
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

// strcmp: compare strings at r3 and r4. ZF=1 if equal
strcmp:
.Lsc_loop:
    lbz     %r5, 0(%r3)
    lbz     %r6, 0(%r4)
    cmpw    %r5, %r6
    bne     .Lsc_done
    cmpwi   %r5, 0
    beq     .Lsc_done
    addi    %r3, %r3, 1
    addi    %r4, %r4, 1
    b       .Lsc_loop
.Lsc_done:
    blr

print_str:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    mr      %r4, %r3
.Lps_loop:
    lbz     %r5, 0(%r4)
    cmpwi   %r5, 0
    beq     .Lps_done
    mr      %r3, %r5
    bl      uart_putc
    addi    %r4, %r4, 1
    b       .Lps_loop
.Lps_done:
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

print_crlf:
    mflr    %r0
    stw     %r0, -8(%r1)
    stwu    %r1, -16(%r1)
    li      %r3, 0x0D
    bl      uart_putc
    li      %r3, 0x0A
    bl      uart_putc
    addi    %r1, %r1, 16
    lwz     %r0, -8(%r1)
    mtlr    %r0
    blr

uart_putc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300
.Lup_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x20
    beq     .Lup_wait
    stb     %r3, 0(%r8)
    blr

uart_getc:
    lis     %r8, 0xEF60
    ori     %r8, %r8, 0x0300
.Lug_wait:
    lbz     %r9, 5(%r8)
    andi.   %r9, %r9, 0x01
    beq     .Lug_wait
    lbz     %r3, 0(%r8)
    blr

// ---- Data ----
msg_bn:  .asciz "PPC MiniShell\n"
msg_pr:  .asciz "> "
msg_hi:  .asciz "Hello, PowerPC!\n"
msg_h1:  .asciz "Commands: hello, help, quit\n"
msg_h2:  .asciz "  hello - Say hello\n"
msg_h3:  .asciz "  quit  - Exit\n"
msg_bye: .asciz "Bye!\n"
msg_unk: .asciz "Unknown command\n"
cmd_hello: .asciz "hello"
cmd_help:  .asciz "help"
cmd_quit:  .asciz "quit"
input:     .space 32