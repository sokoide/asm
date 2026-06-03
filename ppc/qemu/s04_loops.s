// s04_loops.s - Scenario 4: Loops and Conditional Branching
.section .text
.global _start
_start:
    lis     %r1, 0x0000
    ori     %r1, %r1, 0x1000

    // Countdown 5->1
    lis     %r3, msg_dn@ha; addi %r3,%r3,msg_dn@l; bl print_str
    li      %r30, 5
.cd: addi %r3,%r30,0x30; bl uart_putc
    li %r3,0x20; bl uart_putc
    addic. %r30,%r30,-1; bne .cd
    bl print_crlf

    // Count-up 1->5
    lis     %r3, msg_up@ha; addi %r3,%r3,msg_up@l; bl print_str
    li      %r30, 1
.cu: addi %r3,%r30,0x30; bl uart_putc
    li %r3,0x20; bl uart_putc
    addi %r30,%r30,1; cmpwi %r30,6; blt .cu
    bl print_crlf

    // Even 2,4,6,8
    lis     %r3, msg_ev@ha; addi %r3,%r3,msg_ev@l; bl print_str
    li      %r30, 2
.ev: andi. %r9,%r30,1; bne .sk
    addi %r3,%r30,0x30; bl uart_putc
    li %r3,0x20; bl uart_putc
.sk: addi %r30,%r30,1; cmpwi %r30,10; blt .ev
    bl print_crlf

halt: b halt

print_str:
    mflr %r0; stw %r0,-8(%r1); stwu %r1,-16(%r1)
    mr %r4,%r3
.ps: lbz %r5,0(%r4); cmpwi %r5,0; beq .pd
    mr %r3,%r5; bl uart_putc; addi %r4,%r4,1; b .ps
.pd: addi %r1,%r1,16; lwz %r0,-8(%r1); mtlr %r0; blr

print_crlf:
    mflr %r0; stw %r0,-8(%r1); stwu %r1,-16(%r1)
    addi %r3,%r0,0x0D; bl uart_putc; addi %r3,%r0,0x0A; bl uart_putc
    addi %r1,%r1,16; lwz %r0,-8(%r1); mtlr %r0; blr

uart_putc:
    lis %r8,0xef60; ori %r8,%r8,0x0300
.uw: lbz %r9,5(%r8); andi. %r9,%r9,0x20; beq .uw; stb %r3,0(%r8); blr

msg_dn: .asciz "Countdown: "
msg_up: .asciz "Count-up:  "
msg_ev: .asciz "Even:      "
