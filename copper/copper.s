	.org $e00
	
	.temps $70..$8f
	
entry_point:
	.(
	lda #0
	jsr mos_setmode
	jsr fillscreen3
	jsr setpalette
	;jsr iter
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
	lda #170
	sta (%ptr),y
	iny
	lda #85
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
	jmp twoway2_50
	
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
