	.org $e05
	
	.temps $70..$7f
	
	.alias total_lines 39
	.alias displayed_lines 32
	.alias top_screen_lines 30
	
start:
	lda #2
	jsr mos_setmode
	jsr stripes
	jsr blocks
	jsr initvsync
spin
	;jmp spin
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
	lda SYS_T1C_L
	sta (%ptr),y
	iny
	bne loop2
	
	inc %ptr+1
	lda %ptr+1
	cmp #$80
	bne loop
	
	.)
	.ctxend
	
	.macro crtc_write addr data
	lda #%addr
	sta CRTC_ADDR
	lda %data
	sta CRTC_DATA
	.mend
	
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
	;lda #0b01011000
	; CB1 & CB2 only
	lda #0b00011000
	; or everything!
	;lda #0b01111101
	sta SYS_IER

        cli
        
	lda #0
	sta v_offset
	
        rts
	.)

v_offset
	.byte 0

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

	.(
	lda first_after_vsync
	beq disable_irq
	
	; First IRQ in the new CRTC cycle: set some registers
	; CRTC cycle length = 16 rows
	@crtc_write 4, {#top_screen_lines-1}
	@crtc_write 6, {#top_screen_lines}
	@crtc_write 7, {#255}
	lda #5
	sta CRTC_ADDR
	lda v_offset
	and #7
	inc a
	sta CRTC_DATA

	@crtc_write 12, {#>[$3000/8]}
	@crtc_write 13, {#<[$3000/8]}

	stz first_after_vsync

	bra not_last

disable_irq
	; Disable usr timer1 interrupt
	lda #0b01000000
	sta USR_IER
	lda #255
	sta USR_T1L_L
	sta USR_T1L_H
	
	; remaining rows
	@crtc_write 4, {#total_lines-top_screen_lines-2}
	@crtc_write 6, {#displayed_lines-top_screen_lines}
	@crtc_write 7, {#total_lines-top_screen_lines-5}
not_last
	.)

	ply
	plx
	pla
	sta $fc
	rti

new_cycle_time
	.word 64 * 40

first_after_vsync
	.byte 0

	.alias tmp $80
	.alias tmp2 $82

vsync
	phx
	phy

	; Clear interrupt
	lda USR_T1C_L

        ; Trigger after 'new_cycle_time' microseconds
        lda new_cycle_time
        sta USR_T1C_L
        lda new_cycle_time+1
        sta USR_T1C_H

	; Latch the time for the subsequent flip -- for the secondary CRTC
	; cycle.
	lda #<[64*8*top_screen_lines-2]
	sta USR_T1L_L
	lda #>[64*8*top_screen_lines-2]
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

	inc v_offset

	;@crtc_write 12, {#>[$3000/8]}
	;@crtc_write 13, {#<[$3000/8]}
	
	; tmp = (v_offset & ~7) << 1
	stz tmp+1
	lda v_offset
	and #$f8
	asl a
	rol tmp+1
	sta tmp
	
	; tmp2 = tmp << 2
	lda tmp+1
	sta tmp2+1
	lda tmp
	asl a
	rol tmp2+1
	asl a
	rol tmp2+1
	sta tmp2
	
	; tmp += tmp2
	lda tmp
	clc
	adc tmp2
	sta tmp
	lda tmp+1
	adc tmp2+1
	sta tmp+1
	
	lda #13
	sta CRTC_ADDR
	lda #<[$3000/8]
	clc
	adc tmp
	sta CRTC_DATA
	
	lda #12
	sta CRTC_ADDR
	lda #>[$3000/8]
	adc tmp+1
	sta CRTC_DATA
	
	lda #5
	sta CRTC_ADDR
	lda v_offset
	and #7
	eor #7
	sta CRTC_DATA

	; gtfo
	ply
	plx
	pla
	sta $fc
	rti
	;jmp (oldirq1v)
	.)
