	.org $e00
	
	.temps $70..$8d
	
start:
	lda #2
	jsr mos_setmode
	jsr stripes
	jsr blocks
	jsr initvsync
spin
	jmp spin
	rts
	
	.include "../lib/mos.s"
	
	.context stripes
	.var2 ptr
stripes
	lda #<$3000
	sta %ptr
	lda #>$3000
	sta %ptr+1
	.(
loop:
	ldy #0
loop2:
	lda #$11
	sta (%ptr),y
	iny
	bne loop2
	
	inc %ptr+1
	lda %ptr+1
	cmp #$80
	bne loop
	
	.)
	.ctxend
	
	.context blocks
blocks:
	rts
	.ctxend

; TODO: implement http://www.retrosoftware.co.uk/wiki/index.php/\
;   How_to_do_the_smooth_vertical_scrolling

initvsync
	.(
	sei

        lda $204
        ldx $205
        sta oldirq1v
        stx oldirq1v+1

        ; Set one-shot mode for timer 1
        ;lda USR_ACR
        ;and #$0b00111111
        ;sta USR_ACR
        
        ; Sys VIA CA1 interrupt on positive edge
        lda SYS_PCR
        ora #$1
        sta SYS_PCR
                
        ; Point at IRQ handler
        lda #<irq1
        ldx #>irq1
        sta $204
        stx $205

        ; Enable Usr timer 1 interrupt
        ;lda #$c0
        ;sta USR_IER
	
	; Disable USR_IER bits
	;lda #0b00111111
	;sta USR_IER
        
	lda SYS_IER
	sta old_sys_ier
	
        ; Enable Sys CA1 interrupt.
        lda #0b10000010
        sta SYS_IER
        
	; Disable Sys CB1, CB2, timer1 interrupts
	; Note turning off sys timer1 interrupt breaks a lot of stuff!
	lda #0b01011000
	; CB1 & CB2 only
	;lda #0b00011000
	; or everything!
	;lda #0b01111101
	sta SYS_IER

        cli
        
        rts
	.)

old_sys_ier
	.byte 0
oldirq1v
	.word 0

irq1:	.(
	lda $fc
        pha

        ; Is it our User VIA timer1 interrupt?
        lda #64
        bit USR_IFR
        bne timer1
        ; Is it our System VIA CA1 interrupt?
	lda #2
        bit SYS_IFR
        bne vsync
        
        pla
	sta $fc
        jmp (oldirq1v)

timer1
	; Clear interrupt
	lda USR_T1C_L

	phx
	phy

	; Latch next timeout
	lda #<[64*2-2]
	sta USR_T1L_L
	lda #>[64*2-2]
	sta USR_T1L_H

	.(
	lda first_after_vsync
	bne not_last

	; Disable usr timer1 interrupt
	lda #0b01000000
	sta USR_IER
	lda #255
	sta USR_T1L_L
	sta USR_T1L_H
not_last
	.)

	stz first_after_vsync

	ply
	plx
	pla
	sta $fc
	rti

fliptime
	.word 64 * 28 + 37

first_after_vsync
	.byte 0

vsync
	phx
	phy

	; Clear interrupt
	lda USR_T1C_L

        ; Trigger after 'fliptime' microseconds
        lda fliptime
        sta USR_T1C_L
        lda fliptime+1
        sta USR_T1C_H

	lda #<[64*2-2]
	sta USR_T1L_L
	lda #>[64*2-2]
	sta USR_T1L_H

	; Clear IFR
	lda SYS_ORA
	
	; Generate stream of interrupts
	lda USR_ACR
	and #0b00111111
	ora #0b01000000
	sta USR_ACR
       
	; Enable usr timer1 interrupt
	lda #0b11000000
	sta USR_IER

	lda #1
	sta first_after_vsync

	; gtfo
	ply
	plx
	pla
	sta $fc
	rti
	; jmp (oldirq1v)
	.)
