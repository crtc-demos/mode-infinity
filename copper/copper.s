	.org $e00
	
	.temps $70..$8d
	
entry_point:
	.(
	lda #0
	jsr mos_setmode
	jsr fillscreen
	;jsr setpalette
	;jsr iter
	jsr initvsync
spin
	jmp spin
	rts
	.)

	.include "../lib/mos.s"
	
	.context fillscreen
	.var2 ptr
fillscreen
	lda #<$3000
	sta %ptr
	lda #>$3000
	sta %ptr+1
	ldy #0
loop
	lda #0b00000000
	sta (%ptr),y
	iny
	lda #0b00000000
	sta (%ptr),y
	iny
	lda #0b00000000
	sta (%ptr),y
	iny
	lda #0b00000000
	sta (%ptr),y
	iny
	cpy #0
	bne loop

	inc %ptr+1
	lda %ptr+1
	cmp #>$8000
	bne loop

	rts
	.ctxend

	.context fillscreen3
	.var2 ptr
fillscreen3
	lda #<$3000
	sta %ptr
	lda #>$3000
	sta %ptr+1
	ldy #0
loop
	lda #0b01011101
	sta (%ptr),y
	iny
	lda #0b10101010
	sta (%ptr),y
	iny
	lda #0b11101110
	sta (%ptr),y
	iny
	lda #0b01010101
	sta (%ptr),y
	iny
	cpy #0
	bne loop

	inc %ptr+1
	lda %ptr+1
	cmp #>$8000
	bne loop

	rts
	.ctxend

tops:
	.byte 0x6d
	.byte 0xb6
	.byte 0xdb
bottoms:
	.byte 0xb6
	.byte 0xdb
	.byte 0x6d

	.context fillscreen2
	.var2 ptr
fillscreen2
	lda #<$3000
	sta %ptr
	lda #>$3000
	sta %ptr+1
loop
	ldx #0
threecolumns
	ldy #0
column
	lda tops,x
	sta (%ptr),y
	iny
	lda bottoms,x
	sta (%ptr),y
	iny
	cpy #8
	bne column

	lda %ptr
	clc
	adc #8
	sta %ptr
	.(
	bcc nohi
	inc %ptr + 1
nohi
	.)

	inx
	cpx #3
	bne threecolumns

	lda %ptr+1
	cmp #>$8000
	bne loop

	rts
	.ctxend

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

.alias index $8f
.alias max_idx $8e

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

	; Latch next timeout
	lda #<[64*2-2]
	sta USR_T1L_L
	lda #>[64*2-2]
	sta USR_T1L_H

	inc index
	lda index
	cmp max_idx
	.(
	bne not_last
	; Disable usr timer1 interrupt
	lda #0b01000000
	sta USR_IER
	lda #255
	sta USR_T1L_L
	sta USR_T1L_H
not_last
	.)

setpal
	lda #1
	bit index
	beq stripe2

	lda #0b00000001 : sta PALCONTROL	; A
	lda #0b00010001 : sta PALCONTROL	; B
	lda #0b00100001 : sta PALCONTROL	; C
	lda #0b00110001 : sta PALCONTROL	; D
	lda #0b01000001 : sta PALCONTROL	; E
	lda #0b01010001 : sta PALCONTROL	; F
	lda #0b01100001 : sta PALCONTROL	; G
	lda #0b01110001 : sta PALCONTROL	; H

	lda #0b10000011 : sta PALCONTROL	; I
	lda #0b10010011 : sta PALCONTROL	; J
	lda #0b10100011 : sta PALCONTROL	; K
	lda #0b10110011 : sta PALCONTROL	; L
	lda #0b11000011 : sta PALCONTROL	; M
	lda #0b11010011 : sta PALCONTROL	; N
	lda #0b11100011 : sta PALCONTROL	; O
	lda #0b11110011 : sta PALCONTROL	; P

	pla
	sta $fc
	rti

stripe2
	lda #0b00000011 : sta PALCONTROL	; A
	lda #0b00010011 : sta PALCONTROL	; B
	lda #0b00100011 : sta PALCONTROL	; C
	lda #0b00110011 : sta PALCONTROL	; D
	lda #0b01000011 : sta PALCONTROL	; E
	lda #0b01010011 : sta PALCONTROL	; F
	lda #0b01100011 : sta PALCONTROL	; G
	lda #0b01110011 : sta PALCONTROL	; H

	lda #0b10000001 : sta PALCONTROL	; I
	lda #0b10010001 : sta PALCONTROL	; J
	lda #0b10100001 : sta PALCONTROL	; K
	lda #0b10110001 : sta PALCONTROL	; L
	lda #0b11000001 : sta PALCONTROL	; M
	lda #0b11010001 : sta PALCONTROL	; N
	lda #0b11100001 : sta PALCONTROL	; O
	lda #0b11110001 : sta PALCONTROL	; P

	pla
	sta $fc
	rti

fliptime
	.word 64 * 28 + 40

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
       
	lda #0
	sta index
	lda #128
	sta max_idx

	; Enable usr timer1 interrupt
	lda #0b11000000
	sta USR_IER

	; gtfo
	ply
	plx
	pla
	sta $fc
	rti
	; jmp (oldirq1v)
	.)

; Now, we have:
;   0  1  0  1  0  1  0  1
;   1  0  1  0  1  0  1  0
; A half-way dither pattern might look like:
;   R  R  R  Y  R  R  R  Y
;   R  Y  R  R  R  Y  R  R
;   ^                    ^
;   pos 7            pos 0
;
; The palette is used to map pixel values like so:
;
; - for the leftmost pixel, we take bits 7, 5, 3, 1 of a screen byte.
; - look up in 16-entry palette, XOR result with 7.
; - for the next leftmost pixel, shift the screen byte left and OR with 1.
; - look up in 16-entry palette, XOR result with 7.
; - ...and so on until we have coloured 8 pixels.
;
; Now, with our dither pattern layout, we have a sequence:
; (top row)	(bottom row)
; 0 0 0 0 (Y)	1 1 1 1 (R)
; 1 1 1 1 (R)	0 0 0 0 (Y)
; 0 0 0 1 (R)	1 1 1 1 (R)
; 1 1 1 1 (R)	0 0 0 1 (R)
; 0 0 1 1 (Y)	1 1 1 1 (R)
; 1 1 1 1 (R)	0 0 1 1 (Y)
; 0 1 1 1 (R)	1 1 1 1 (R)
; 1 1 1 1 (R)	0 1 1 1 (R)
;
; This isn't quite as nice as I'd hoped :-(.
;
; With a fatter dither pattern we could have:
;   0  0  1  1  0  0  1  1
;   1  1  0  0  1  1  0  0
;
; (top row)	(bottom row)
; 0 1 0 1	1 0 1 0
; 0 1 0 1	...
; 1 0 1 1
; 1 0 1 1
; 0 1 1 1
; 0 1 1 1
; 1 1 1 1
; 1 1 1 1
; this isn't any good!
;
; does a 3-based pattern help?
;  0 0 0 1 1 1 0 0 : 0 1 1 1 0 0 0 1 : 1 1 0 0 0 1 1 1
;  1 1 1 0 0 0 1 1 : 1 0 0 0 1 1 1 0 : 0 0 1 1 1 0 0 0
;
; (top row)	(bottom row)
; 0 0 1 0	1 1 0 0		0 0 0 0		A
; 0 1 1 0	1 0 0 1		0 0 0 1		B
; 0 1 0 1	1 0 1 1		0 0 1 0		C
; 1 1 0 1	0 0 1 1		0 0 1 1		D
; 1 0 1 1	0 1 1 1		0 1 0 0		E
; 1 0 1 1	0 1 1 1		0 1 0 1		F
; 0 1 1 1	1 1 1 1		0 1 1 0		G
; 0 1 1 1	1 1 1 1		0 1 1 1		H
;				1 0 0 0		I
; 0 1 0 0	1 0 1 1		1 0 0 1		J
; 1 1 0 1	0 0 1 0		1 0 1 0		K
; 1 0 0 1	0 1 1 1		1 0 1 1		L
; 1 0 1 1	0 1 0 1		1 1 0 0		M
; 0 0 1 1	1 1 1 1		1 1 0 1		N
; 0 1 1 1	1 0 1 1		1 1 1 0		O
; 0 1 1 1	1 1 1 1		1 1 1 1		P
; 1 1 1 1	1 1 1 1
;
; 1 0 0 1	0 1 1 0
; 1 0 1 1	0 1 0 0
; 0 0 1 1	1 1 0 1
; 0 1 1 1	1 0 0 1
; 0 1 1 1	1 0 1 1
; 1 1 1 1	0 0 1 1
; 1 1 1 1	0 1 1 1
; 1 1 1 1	0 1 1 1
;
; cgfnllhh enjldhhp jldhhppp
; njldhhpp lchfplph genjldhh
;
; 2C 4D 2E 2F 2G 11H 4J 7L 1M 4N 9P
;       ^^               

	.context setpalette
setpalette
	jmp twoway2_375
	
	lda #155
	ldx #0b00000001 : jsr osbyte
	ldx #0b00010001 : jsr osbyte
	ldx #0b00100001 : jsr osbyte
	ldx #0b00110001 : jsr osbyte
	ldx #0b01000001 : jsr osbyte
	ldx #0b01010001 : jsr osbyte
	ldx #0b01100001 : jsr osbyte
	ldx #0b01110001 : jsr osbyte
	
	ldx #0b10000011 : jsr osbyte
	ldx #0b10010011 : jsr osbyte
	ldx #0b10100011 : jsr osbyte
	ldx #0b10110011 : jsr osbyte
	ldx #0b11000011 : jsr osbyte
	ldx #0b11010011 : jsr osbyte
	ldx #0b11100011 : jsr osbyte
	ldx #0b11110011 : jsr osbyte
partial
	lda #155
	ldx #0b00000011 : jsr osbyte
	ldx #0b00010001 : jsr osbyte
	ldx #0b00100000 : jsr osbyte
	ldx #0b00110011 : jsr osbyte
	ldx #0b01000000 : jsr osbyte
	ldx #0b01010000 : jsr osbyte
	ldx #0b01100000 : jsr osbyte
	ldx #0b01110001 : jsr osbyte

	ldx #0b10000000 : jsr osbyte
	ldx #0b10010000 : jsr osbyte
	ldx #0b10100000 : jsr osbyte
	ldx #0b10110000 : jsr osbyte
	ldx #0b11000000 : jsr osbyte
	ldx #0b11010000 : jsr osbyte
	ldx #0b11100000 : jsr osbyte
	ldx #0b11110001 : jsr osbyte

threeway
	lda #155
	ldx #0b00000001 : jsr osbyte		; A
	ldx #0b00010001 : jsr osbyte		; B
	ldx #0b00100011 : jsr osbyte		; C
	ldx #0b00110011 : jsr osbyte		; D
	ldx #0b01000001 : jsr osbyte		; E
	ldx #0b01010001 : jsr osbyte		; F
	ldx #0b01100001 : jsr osbyte		; G
	ldx #0b01110001 : jsr osbyte		; H

	ldx #0b10000001 : jsr osbyte		; I
	ldx #0b10010001 : jsr osbyte		; J
	ldx #0b10100001 : jsr osbyte		; K
	ldx #0b10110001 : jsr osbyte		; L
	ldx #0b11000001 : jsr osbyte		; M
	ldx #0b11010001 : jsr osbyte		; N
	ldx #0b11100001 : jsr osbyte		; O
	ldx #0b11110011 : jsr osbyte		; P

twoway2_125
	lda #155
	ldx #0b00000011 : jsr osbyte		; A
	ldx #0b00010001 : jsr osbyte		; B
	ldx #0b00100001 : jsr osbyte		; C
	ldx #0b00110001 : jsr osbyte		; D
	ldx #0b01000001 : jsr osbyte		; E
	ldx #0b01010001 : jsr osbyte		; F
	ldx #0b01100001 : jsr osbyte		; G
	ldx #0b01110001 : jsr osbyte		; H

	ldx #0b10000011 : jsr osbyte		; I
	ldx #0b10010001 : jsr osbyte		; J
	ldx #0b10100001 : jsr osbyte		; K
	ldx #0b10110011 : jsr osbyte		; L
	ldx #0b11000001 : jsr osbyte		; M
	ldx #0b11010001 : jsr osbyte		; N
	ldx #0b11100001 : jsr osbyte		; O
	ldx #0b11110001 : jsr osbyte		; P
	rts

twoway2_25
	lda #155
	ldx #0b00000001 : jsr osbyte		; A
	ldx #0b00010011 : jsr osbyte		; B
	ldx #0b00100001 : jsr osbyte		; C
	ldx #0b00110001 : jsr osbyte		; D
	ldx #0b01000001 : jsr osbyte		; E
	ldx #0b01010011 : jsr osbyte		; F
	ldx #0b01100001 : jsr osbyte		; G
	ldx #0b01110011 : jsr osbyte		; H

	ldx #0b10000001 : jsr osbyte		; I
	ldx #0b10010001 : jsr osbyte		; J
	ldx #0b10100001 : jsr osbyte		; K
	ldx #0b10110001 : jsr osbyte		; L
	ldx #0b11000001 : jsr osbyte		; M
	ldx #0b11010001 : jsr osbyte		; N
	ldx #0b11100001 : jsr osbyte		; O
	ldx #0b11110001 : jsr osbyte		; P
	rts

twoway2_375
	lda #155
	ldx #0b00000011 : jsr osbyte		; A
	ldx #0b00010011 : jsr osbyte		; B
	ldx #0b00100001 : jsr osbyte		; C
	ldx #0b00110001 : jsr osbyte		; D
	ldx #0b01000001 : jsr osbyte		; E
	ldx #0b01010011 : jsr osbyte		; F
	ldx #0b01100001 : jsr osbyte		; G
	ldx #0b01110011 : jsr osbyte		; H

	ldx #0b10000011 : jsr osbyte		; I
	ldx #0b10010001 : jsr osbyte		; J
	ldx #0b10100001 : jsr osbyte		; K
	ldx #0b10110011 : jsr osbyte		; L
	ldx #0b11000001 : jsr osbyte		; M
	ldx #0b11010001 : jsr osbyte		; N
	ldx #0b11100001 : jsr osbyte		; O
	ldx #0b11110001 : jsr osbyte		; P
	rts

twoway2_50
	lda #155
	ldx #0b00000011 : jsr osbyte		; A
	ldx #0b00010011 : jsr osbyte		; B
	ldx #0b00100011 : jsr osbyte		; C
	ldx #0b00110011 : jsr osbyte		; D
	ldx #0b01000001 : jsr osbyte		; E
	ldx #0b01010011 : jsr osbyte		; F
	ldx #0b01100001 : jsr osbyte		; G
	ldx #0b01110011 : jsr osbyte		; H

	ldx #0b10000011 : jsr osbyte		; I
	ldx #0b10010001 : jsr osbyte		; J
	ldx #0b10100011 : jsr osbyte		; K
	ldx #0b10110011 : jsr osbyte		; L
	ldx #0b11000001 : jsr osbyte		; M
	ldx #0b11010001 : jsr osbyte		; N
	ldx #0b11100001 : jsr osbyte		; O
	ldx #0b11110001 : jsr osbyte		; P

	rts
	.ctxend

	.context iter
	.var2 ptr
	.var val
iter
	lda #<$3000
	sta %ptr
	lda #>$3000
	sta %ptr+1
	ldy #0
loop
	lda %val
	sta (%ptr),y
	iny
	cpy #0
	bne loop

	inc %ptr+1
	lda %ptr+1
	cmp #>$8000
	bne loop

	inc %val
	jmp iter

	rts
	.ctxend
