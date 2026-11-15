; s103_irq_nmi.s - Scenario 103: IRQ & NMI (sim65i extension, arch-specific)
; ==========================================================================
; The 6502 has two hardware interrupt inputs:
;
;   IRQ  (level, maskable)   vector $FFFE/$FFFF - taken only when I flag = 0
;   NMI  (edge, non-maskable) vector $FFFA/$FFFB - always taken
;
; On entry the CPU pushes PC (2 bytes) and P with B=0 (hardware interrupt),
; sets I=1, and jumps through the vector. RTI restores P and PC.
; Interrupt entry costs 7 cycles, RTI costs 6 cycles (6502 datasheet).
;
; The stock cc65 sim65 has the IRQ/NMI machinery inside the CPU core
; (IRQRequest/NMIRequest, taken at the instruction boundary) but no caller.
; The repo-local build "sim65i" (sim65src/) wires it up: a write to
;
;   $FFCC  raises an IRQ pulse   (value written is ignored)
;   $FFCE  raises an NMI pulse
;
; This is the educational stand-in for a peripheral asserting its line.
; Simplification vs. real hardware: the request is latched until accepted.
; A real level-triggered IRQ would be lost if the device released the line
; before I was cleared - here an IRQ triggered while I=1 is delivered
; right after the CLI re-enables interrupts (see Demo 2).

.import print_str, print_nl, print_hex8, print_dec, _putchar
.export _main

.segment "ZEROPAGE"
irq_count:  .res 1    ; incremented by the IRQ handler
nmi_count:  .res 1    ; incremented by the NMI handler

.segment "RODATA"
msg_hdr:    .asciiz "--- IRQ & NMI (sim65i) ---"
msg_d1:     .asciiz "Demo1 IRQ (I=0):     "
msg_d1c:    .asciiz "  -> irq_count = "
msg_d2:     .asciiz "Demo2 IRQ masked:    "
msg_d2c:    .asciiz "  -> delivered after CLI, irq_count = "
msg_d3:     .asciiz "Demo3 NMI (I=1):     "
msg_d3c:    .asciiz "  -> nmi_count = "

.segment "CODE"
_main:
; ---- Vector setup: write handler addresses into $FFFA/$FFFE ----
    lda #<irq_handler
    sta $FFFE               ; IRQ vector low
    lda #>irq_handler
    sta $FFFF               ; IRQ vector high
    lda #<nmi_handler
    sta $FFFA               ; NMI vector low
    lda #>nmi_handler
    sta $FFFB               ; NMI vector high
    lda #0
    sta irq_count
    sta nmi_count

    lda #<msg_hdr
    ldx #>msg_hdr
    jsr print_str
    jsr print_nl

; ---- Demo 1: IRQ taken while I=0 ----
; IRQ entry (7) -> handler -> RTI (6). The STA $FFF0 completes first,
; the interrupt is taken at the next instruction boundary.
    lda #<msg_d1
    ldx #>msg_d1
    jsr print_str
    cli                     ; I=0: IRQ enabled
    sta $FFCC               ; trigger IRQ pulse (A value ignored)
    nop                     ; <- execution resumes here after RTI
    lda #<msg_d1c
    ldx #>msg_d1c
    jsr print_str
    lda irq_count
    jsr print_dec
    jsr print_nl

; ---- Demo 2: IRQ masked by I=1, delivered after CLI ----
; SEI masks the IRQ (latched in sim65i), CLI hands it over immediately.
    lda #<msg_d2
    ldx #>msg_d2
    jsr print_str
    sei                     ; I=1: IRQ masked
    sta $FFCC               ; trigger IRQ pulse - NOT taken now
    nop                     ; still no interrupt (I=1)
    lda #<msg_d2c
    ldx #>msg_d2c
    jsr print_str
    cli                     ; I=0 -> latched IRQ delivered here
    lda irq_count
    jsr print_dec
    jsr print_nl

; ---- Demo 3: NMI ignores the I flag ----
; NMI is edge-triggered and non-maskable: taken even with I=1.
    lda #<msg_d3
    ldx #>msg_d3
    jsr print_str
    sei                     ; I=1: would mask IRQ, but not NMI
    sta $FFCE               ; trigger NMI pulse
    nop                     ; <- execution resumes here after RTI
    lda #<msg_d3c
    ldx #>msg_d3c
    jsr print_str
    lda nmi_count
    jsr print_dec
    jsr print_nl

    lda #0                  ; exit code 0 (crt0 calls exit -> PVExit)
    rts

; ---- IRQ handler: increment counter, print, return ----
; Entry: P pushed with B=0, I=1 set by hardware. A/X/Y are saved here
; because _putchar's paravirt hook must not corrupt the interrupted code.
irq_handler:
    pha
    txa
    pha
    tya
    pha
    inc irq_count
    lda #'<'
    jsr _putchar
    lda #'>'
    jsr _putchar
    pla
    tay
    pla
    tax
    pla
    rti

; ---- NMI handler: same pattern ----
nmi_handler:
    pha
    txa
    pha
    tya
    pha
    inc nmi_count
    lda #'{'
    jsr _putchar
    lda #'}'
    jsr _putchar
    pla
    tay
    pla
    tax
    pla
    rti
