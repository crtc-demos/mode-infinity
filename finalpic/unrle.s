	;.temps $b0..$bf

	;.org $1200

	.macro dummy
entry:
	lda #1
	jsr mos_setmode
	jsr mos_cursoroff
	
	lda #12
	jsr oswrch
	
	@load_file_to owl_rle, $3000

	lda #5
	jsr select_sram

	ldx #<$8000
	ldy #>$8000
	lda #>[10839+255]
	jsr copy_to_sram

	ldx #<$8000
	ldy #>$8000
	jsr do_unpack
	
	jsr select_old_lang
	
	rts

	; Unpack data in Y:X to screen address.
do_unpack:
	stx %unpack_rle.start_address
	sty %unpack_rle.start_address + 1
	lda #<$3000
	sta %unpack_rle.screenptr
	lda #>$3000
	sta %unpack_rle.screenptr + 1
	jmp unpack_rle	

;owl_rle:
;	.asc "owl3z",13

	.mend

	.context unpack_rle
	; Inputs:
	;    start_address: start of RLE data
	;    screenptr: output pointer.
	.var2 start_address, screenptr
	.var length, write_byte
unpack_rle:

rle_loop:
	; byte to write
	ldy #1
	lda (%start_address), y
	sta %write_byte

	; ...this number of times
	lda (%start_address)
	cmp #192
	bcs do_block
	; Length zero encodes a repetition of 192 times.
	.(
	cmp #0
	bne not_192
	lda #192
not_192:
	.)
	sta %length

	tay

	lda %write_byte

	.(
fill_loop
	dey
	sta (%screenptr), y
	cpy #0
	bne fill_loop
	.)

	lda %screenptr
	clc
	adc %length
	sta %screenptr
	.(
	bcc no_hi
	inc %screenptr + 1
no_hi:	.)

	lda %start_address
	clc
	adc #2
	sta %start_address
	.(
	bcc no_hi
	inc %start_address + 1
no_hi
	.)

	bra done_elem
	
	; A block of low repetition-rate bytes.
do_block
	sec
	sbc #192
	bne not_sixteen
	lda #64
not_sixteen
	sta %length
	tay
	.(
	inc %start_address
	bne nohi
	inc %start_address+1
nohi:	.)
	
	.(
fill_loop
	dey
	lda (%start_address),y
	sta (%screenptr),y
	cpy #0
	bne fill_loop
	.)
	
	lda %screenptr
	clc
	adc %length
	sta %screenptr
	.(
	bcc nohi
	inc %screenptr+1
nohi:	.)

	lda %start_address
	clc
	adc %length
	sta %start_address
	.(
	bcc nohi
	inc %start_address+1
nohi:	.)
	
done_elem:
	lda %screenptr + 1
	cmp #$80
	bcc rle_loop

	rts
	.ctxend

	;.include "../lib/mos.s"
	;.include "../lib/load.s"
	;.include "../lib/sram.s"
	
