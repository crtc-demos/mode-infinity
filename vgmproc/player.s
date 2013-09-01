	.org $e05
	
	.temps $70..$7f
start:
	jsr play_it
	rts
	
	.include "../lib/mos.s"
	.include "ice.s"

chan0_pitch:
	.byte 0
chan1_pitch:
	.byte 0
chan2_pitch:
	.byte 0
chan3_pitch:
	.byte 0

pe0_pos:
	.word 0
pe1_pos:
	.word 0
pe2_pos:
	.word 0
pe3_pos:
	.word 0

ve0_pos:
	.word 0
ve1_pos:
	.word 0
ve2_pos:
	.word 0
ve3_pos:
	.word 0

beatpos:
	.byte 0

	; Input: A
	; Output: A (lo), X (hi)
	.context tx18
	.var2 tmp, tmp2    
tx18
	; %tmp = <input>*2
	stz %tmp+1
	asl a
	rol %tmp+1
	sta %tmp
	
	; %tmp2 = <input>*16
	ldx %tmp+1
	stx %tmp2+1
	asl a
	rol %tmp2+1
	asl a
	rol %tmp2+1
	asl a
	rol %tmp2+1
	
	clc
	adc %tmp
	tay
	lda %tmp2+1
	adc %tmp+1
	tax
	tya
	
	rts
	.ctxend

	; Input: A
	; Output: A (lo), X (hi)
	.context tx36
	.var2 tmp, tmp2    
tx36
	; %tmp = <input>*4
	stz %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	sta %tmp
	
	; %tmp2 = <input>*32
	ldx %tmp+1
	stx %tmp2+1
	asl a
	rol %tmp2+1
	asl a
	rol %tmp2+1
	asl a
	rol %tmp2+1
	
	clc
	adc %tmp
	tay
	lda %tmp2+1
	adc %tmp
	tax
	tya
	
	rts
	.ctxend

	.context psg_strobe
psg_strobe:
	sei
	ldy #255
	sty $fe43
	
	sta $fe41
	stz $fe40
	nop
	nop
	nop
	nop
	nop
	nop
	lda #$08
	sta $fe40
	cli
	rts
	.ctxend

	.macro init_vpos playpos offset addrbase posidx
	ldy #%offset
	lda (%playpos),y
	jsr tx18
	clc
	adc #<%addrbase
	sta %posidx
	txa
	adc #>%addrbase
	sta %posidx+1
	.mend

	.macro init_ppos playpos offset addrbase posidx
	ldy #%offset
	lda (%playpos),y
	jsr tx36
	clc
	adc #<%addrbase
	sta %posidx
	txa
	adc #>%addrbase
	sta %posidx+1
	.mend

	.context play_it
	.var2 playpos
	.var2 pitchenvpos
	.var2 volenvpos, tmp
play_it:
	lda #<song_notes
	sta %playpos
	lda #>song_notes
	sta %playpos+1
	
loop:
	ldy #0
	lda (%playpos),y
	sta chan0_pitch
	ldy #3
	lda (%playpos),y
	sta chan1_pitch
	ldy #6
	lda (%playpos),y
	sta chan2_pitch
	ldy #9
	lda (%playpos),y
	sta chan3_pitch
	
	@init_vpos %playpos, 1, song_pitchenv, pe0_pos
	@init_vpos %playpos, 2, song_volenv, ve0_pos
	@init_vpos %playpos, 4, song_pitchenv, pe1_pos
	@init_vpos %playpos, 5, song_volenv, ve1_pos
	@init_vpos %playpos, 7, song_pitchenv, pe2_pos
	@init_vpos %playpos, 8, song_volenv, ve2_pos
	@init_vpos %playpos, 10, song_pitchenv, pe3_pos
	@init_vpos %playpos, 11, song_volenv, ve3_pos
	
	lda #0
	sta beatpos
beat:
	; channel 0
	ldy beatpos
	lda ve0_pos
	sta %volenvpos
	lda ve0_pos+1
	sta %volenvpos+1
	lda (%volenvpos),y
	ora #0b10010000
	jsr psg_strobe
	
	ldy beatpos
	lda pe0_pos
	sta %pitchenvpos
	lda pe0_pos+1
	sta %pitchenvpos+1
	lda (%pitchenvpos),y
	clc
	adc chan0_pitch
	stz %tmp+1
	asl a
	rol %tmp+1
	clc
	adc #<song_freqtab
	sta %tmp
	lda %tmp+1
	adc #>song_freqtab
	sta %tmp+1
	
	ldy #1
	lda (%tmp),y
	ora #0b10000000
	jsr psg_strobe
	lda (%tmp)
	jsr psg_strobe

	; channel 1
	ldy beatpos
	lda ve1_pos
	sta %volenvpos
	lda ve1_pos+1
	sta %volenvpos+1
	lda (%volenvpos),y
	ora #0b10110000
	jsr psg_strobe
	
	ldy beatpos
	lda pe1_pos
	sta %pitchenvpos
	lda pe1_pos+1
	sta %pitchenvpos+1
	lda (%pitchenvpos),y
	clc
	adc chan1_pitch
	stz %tmp+1
	asl a
	rol %tmp+1
	clc
	adc #<song_freqtab
	sta %tmp
	lda %tmp+1
	adc #>song_freqtab
	sta %tmp+1
	
	ldy #1
	lda (%tmp),y
	ora #0b10100000
	jsr psg_strobe
	lda (%tmp)
	jsr psg_strobe

	; channel 2
	ldy beatpos
	lda ve2_pos
	sta %volenvpos
	lda ve2_pos+1
	sta %volenvpos+1
	lda (%volenvpos),y
	ora #0b11010000
	jsr psg_strobe
	
	ldy beatpos
	lda pe2_pos
	sta %pitchenvpos
	lda pe2_pos+1
	sta %pitchenvpos+1
	lda (%pitchenvpos),y
	clc
	adc chan2_pitch
	stz %tmp+1
	asl a
	rol %tmp+1
	clc
	adc #<song_freqtab
	sta %tmp
	lda %tmp+1
	adc #>song_freqtab
	sta %tmp+1
	
	ldy #1
	lda (%tmp),y
	ora #0b11000000
	jsr psg_strobe
	lda (%tmp)
	jsr psg_strobe

	; channel 3
	ldy beatpos
	lda ve3_pos
	sta %volenvpos
	lda ve3_pos+1
	sta %volenvpos+1
	lda (%volenvpos),y
	ora #0b11110000
	jsr psg_strobe
	
	ldy beatpos
	lda pe3_pos
	sta %pitchenvpos
	lda pe3_pos+1
	sta %pitchenvpos+1
	lda (%pitchenvpos),y
	clc
	adc chan3_pitch
	stz %tmp+1
	asl a
	rol %tmp+1
	clc
	adc #<song_freqtab
	sta %tmp
	lda %tmp+1
	adc #>song_freqtab
	sta %tmp+1
	
	lda (%tmp)
	ora #0b11100000
	jsr psg_strobe

	; ---

	lda #19
	jsr osbyte

	inc beatpos
	lda beatpos
	cmp #18
	bne beat
	
	lda %playpos
	clc
	adc #12
	sta %playpos
	.(
	bcc nohi
	inc %playpos+1
nohi:	.)

	jmp loop
	
	rts
	.ctxend
