	.org $e00
	
	.temps $70..$7f
	
entry_point:
	.(
	lda #0
	jsr mos_setmode
	;jsr fillscreen
	jsr fillscreen3
	;jsr setpalette
	;jsr iter
	jsr initvsync
	.(
spin
	lda frameno+1
	cmp #7
	bne spin
	.)
	
	jsr make_black
	
	.(
spin
	lda frameno+1
	cmp #8
	bne spin
	.)
	
	sei
	lda #0b01000000
	sta USR_IER
	
	lda oldirq1v
	sta $204
	lda oldirq1v+1
	sta $205
	cli
	
	rts
	.)

curs1:
	.word 0
curs2:
	.word 0
curs3:
	.word 0
frameno:
	.word 0

	.context make_black
	.var2 tmp
make_black
	lda #<[selectpal+128]
	sta %tmp
	lda #>[selectpal+128]
	sta %tmp+1
	
	ldy #0
loop
	lda #<black
	sta (%tmp),y
	iny
	lda #>black
	sta (%tmp),y
	iny
	cpy #128
	bne loop
	
	rts
	.ctxend

	.alias idx $80
	.alias tmp $81
	.alias tmp2 $83
	.alias tmp3 $85
swap:
	.(
	lda #<selectpal
	sta tmp
	lda #>selectpal
	sta tmp+1
	
	lda idx
	stz tmp3+1
	asl a
	rol tmp3+1
	sta tmp3
	
	lda tmp
	clc
	adc tmp3
	sta tmp
	lda tmp+1
	adc tmp3+1
	sta tmp+1
	
	lda #<[selectpal+128]
	sta tmp2
	lda #>[selectpal+128]
	sta tmp2+1
	
	lda tmp2
	clc
	adc tmp3
	sta tmp2
	lda tmp2+1
	adc tmp3+1
	sta tmp2+1
	
	lda (tmp)
	tax
	lda (tmp2)
	sta (tmp)
	txa
	sta (tmp2)
	
	ldy #1
	lda (tmp),y
	tax
	lda (tmp2),y
	sta (tmp),y
	txa
	sta (tmp2),y
	
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
	lda #0b11101010
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
        lda #4
        sta SYS_PCR

	lda #0
	sta SYS_ACR
       
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
.alias magic_offset $8d

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
	lda index
not_last
	.)
	clc
	adc magic_offset
	and #63
	asl a
	tax
	jmp (selectpal,x)

fliptime
	.word 64 * 28 + 35

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
       
	lda #255
	sta index
	lda #128
	sta max_idx

	inc magic_offset

	; Enable usr timer1 interrupt
	lda #0b11000000
	sta USR_IER

	lda curs1
	clc
	adc #100
	sta curs1
	.(
	bcc nohi
	inc curs1+1
	lda curs1+1
	and #63
	sta idx
	jsr swap
nohi:	.)

	lda curs2
	clc
	adc #110
	sta curs2
	.(
	bcc nohi
	inc curs2+1
	lda curs2+1
	and #63
	sta idx
	jsr swap
nohi:	.)

	lda curs3
	clc
	adc #155
	sta curs3
	.(
	bcc nohi
	inc curs3+1
	lda curs3+1
	and #63
	sta idx
	jsr swap
nohi:	.)

	.(
	inc frameno
	bne nohi
	inc frameno+1
nohi:	.)

	; gtfo
	ply
	plx
	pla
	sta $fc
	rti
	; jmp (oldirq1v)
	.)

	.macro palette a b c d f h i k l p
	ldx #0b10110111 ^ %l
	ldy #0b11110111 ^ %p
	lda #0b00000111 ^ %a : sta PALCONTROL	    ; A
	lda #0b00010111 ^ %b : sta PALCONTROL	    ; B
	lda #0b00100111 ^ %c : sta PALCONTROL	    ; C
	lda #0b00110111 ^ %d : sta PALCONTROL	    ; D
	lda #0b01010111 ^ %f : sta PALCONTROL	    ; F
	lda #0b01110111 ^ %h : sta PALCONTROL	    ; H
	lda #0b10000111 ^ %i : sta PALCONTROL	    ; I
	lda #0b10100111 ^ %k : sta PALCONTROL	    ; K
	stx PALCONTROL				    ; L
	sty PALCONTROL				    ; P
	jmp done_palette
	.mend

selectpal
	.word pal0
	.word pal1
	.word pal2
	.word pal3
	.word pal4
	.word pal5
	.word pal6
	.word pal7
	.word pal8
	
	.word pal9
	.word pal10
	.word pal11
	.word pal12
	.word pal13
	.word pal14
	.word pal15
	.word pal16
	
	.word pal17
	.word pal18
	.word pal19
	.word pal20
	.word pal21
	.word pal22
	.word pal23
	.word pal24
	
	.word pal25
	.word pal26
	.word pal27
	.word pal28
	.word pal29
	.word pal30
	.word pal31
	.word pal32
	
	.word pal33
	.word pal34
	.word pal35
	.word pal36
	.word pal37
	.word pal38
	.word pal39
	.word pal40
	
	.word pal41
	.word pal42
	.word pal43
	.word pal44
	.word pal45
	.word pal46
	.word pal47
	.word pal48
	
	.word pal49
	.word pal50
	.word pal51
	.word pal52
	.word pal53
	.word pal54
	.word pal55
	.word pal56
	
	.word pal57
	.word pal58
	.word pal59
	.word pal60
	.word pal61
	.word pal62
	.word pal63

	.word pal64
	.word pal65
	.word pal66
	.word pal67
	.word pal68
	.word pal69
	.word pal70
	.word pal71
	.word pal72
	
	.word pal73
	.word pal74
	.word pal75
	.word pal76
	.word pal77
	.word pal78
	.word pal79
	.word pal80
	
	.word pal81
	.word pal82
	.word pal83
	.word pal84
	.word pal85
	.word pal86
	.word pal87
	.word pal88
	
	.word pal89
	.word pal90
	.word pal91
	.word pal92
	.word pal93
	.word pal94
	.word pal95
	.word pal96
	
	.word pal97
	.word pal98
	.word pal99
	.word pal100
	.word pal101
	.word pal102
	.word pal103
	.word pal104
	
	.word pal105
	.word pal106
	.word pal107
	.word pal108
	.word pal109
	.word pal110
	.word pal111
	.word pal112
	
	.word pal113
	.word pal114
	.word pal115
	.word pal116
	.word pal117
	.word pal118
	.word pal119
	.word pal120
	
	.word pal121
	.word pal122
	.word pal123
	.word pal124
	.word pal125
	.word pal126
	.word pal127

	.include "palette"

black:
	@palette 0,0,0,0,0,0,0,0,0,0

done_palette
	ply
	plx
	pla
	sta $fc
	rti


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
	jmp twoway2_25_2
	
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

twoway2_25_2
	lda #155
	ldx #0b00000011 : jsr osbyte		; A
	ldx #0b00010011 : jsr osbyte		; B
	ldx #0b00100011 : jsr osbyte		; C
	ldx #0b00110001 : jsr osbyte		; D
	ldx #0b01000001 : jsr osbyte		; E
	ldx #0b01010001 : jsr osbyte		; F
	ldx #0b01100001 : jsr osbyte		; G
	ldx #0b01110001 : jsr osbyte		; H

	ldx #0b10000001 : jsr osbyte		; I
	ldx #0b10010001 : jsr osbyte		; J
	ldx #0b10100011 : jsr osbyte		; K
	ldx #0b10110011 : jsr osbyte		; L
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
