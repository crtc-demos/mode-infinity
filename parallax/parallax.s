	.org $1200
	
	.temps $70..$7f
	
	.alias total_lines 39
	.alias displayed_lines 32
	.alias top_screen_lines 30

	; These tmps are used from IRQ context. (FIXME: Pasta needs a way of
	; handling IRQ contexts properly.)
	.alias tmp $80
	.alias tmp2 $82
	.alias tmp3 $84
	.alias tmp4 $86
	.alias pal_ptr $88
	.alias offset $8a
	.alias top_small_box_colour $8b
	.alias bg_colour $8c
	.alias small_box_colour $8d
	
start:
	@load_file_to player, music_player

	jsr set_mode_inf

	; Load final pic into SRAM bank 1.

	@load_file_to final_pic, $3000

	lda #BANK1
	jsr select_sram

	ldx #<$8000
	ldy #>$8000
	lda #>[final_pic_size+255]
	jsr copy_to_sram
	
	jsr select_old_lang

	; Shadow bank in main RAM.
	sei
	lda ACCCON
	ora #4
	sta ACCCON
	cli
	@load_file_to copper_effect, $3000
	; Normal screen in main RAM.
	sei
	lda ACCCON
	and #~4
	sta ACCCON
	cli

	jsr music_initialize

	lda #2
	jsr mos_setmode

	jsr stripes
	jsr action_diffs

	lda #7 ^ 7
	jsr recolour_big_boxes

	lda #0 ^ 7
	sta bg_colour
	lda #0 ^ 7
	sta small_box_colour
	jsr recolour_outside_boxes

	jsr initvsync

effect_loop
	lda vsync_ctr
	cmp vsync_ours
	beq effect_loop
	sta vsync_ours

	; Scroll message.
	sei
	lda msg_scrstart
	clc
	adc #1
	sta msg_scrstart
	.(
	bcc nohi
	lda msg_scrstart+1
	adc #0
	cmp #$80/8
	bcc nowrap
	clc
	adc #[$60-$80]/8
nowrap:
	sta msg_scrstart+1
nohi:	.)
	cli

	jsr render_msg_column

	lda effect_state
	cmp #0
	beq just_horiz
	cmp #1
	beq just_vert
	cmp #2
	bcs spinning
	
just_horiz:
	lda #1
	sta %scroll_left.amount
	jsr scroll_left

	.(
	lda vsync_ctr+1
	cmp #4
	bcc keep_going
	inc effect_state
keep_going
	.)

	jmp finish_iteration

just_vert
	inc v_offset_usr
	
	.(
	lda vsync_ctr+1
	cmp #8
	bcc keep_going
	inc effect_state
keep_going
	.)
	jmp finish_iteration

spinning:
	ldx phase+1
	lda sintab,x
	tay
	txa
	clc
	adc #64
	tax
	lda sintab,x
	
	.(
	bpl pos
	ldx #255
	stx utmp
	bra done
pos:	stz utmp
done:	.)
	
	asl a
	rol utmp
	asl a
	rol utmp
	asl a
	rol utmp
	
	clc
	adc vpos
	sta vpos
	lda vpos+1
	adc utmp
	sta vpos+1
	
	lda hpos+1
	sta old_hpos
	
	tya
	.(
	bpl pos
	ldx #255
	stx utmp
	bra done
pos:	stz utmp
done:	.)
	
	asl a
	rol utmp
	
	clc
	adc hpos
	sta hpos
	lda hpos+1
	adc utmp
	sta hpos+1
	
	lda vpos+1
	sta v_offset_usr
	
	.(
	lda old_hpos
	sec
	sbc hpos+1
	beq done
	bmi lower
	sta %scroll_left.amount
	jsr scroll_left
	bra done
lower:
	sta utmp
	lda #0
	sec
	sbc utmp
	sta %scroll_right.amount
	jsr scroll_right
done:	.)
	
	lda phase
	clc
	adc #32
	sta phase
	.(
	bcc nohi
	inc phase+1
nohi:	.)

	; Some colour switching effects
	.(
	lda effect_state
	cmp #3
	bcs end_effect_state

	lda phase+1
	cmp #40
	bcs enable_small_boxes_yellow
	cmp #38
	bcs enable_small_boxes_red
	cmp #36
	bcs goblack
	cmp #34
	bcs goblue
	cmp #32
	bcs gocyan
	bra done

enable_small_boxes_red
	lda #0 ^ 7
	sta bg_colour
	lda #1 ^ 7
	sta small_box_colour
	jsr recolour_outside_boxes
	bra done

enable_small_boxes_yellow
	lda #1 ^ 7
	sta bg_colour
	lda #3 ^ 7
	sta small_box_colour
	jsr recolour_outside_boxes
	inc effect_state
	bra done

gocyan:
	lda #6 ^ 7
	jsr recolour_big_boxes
	bra done

goblue:
	lda #4 ^ 7
	jsr recolour_big_boxes
	bra done

goblack:
	lda #0 ^ 7
	jsr recolour_big_boxes
	bra done
done:
	.)
	bra finish_iteration

	; Effect states 3+ are processed here.
end_effect_state:
	.(
	; Now phase will be going around from 40 upwards.
	lda effect_state
	cmp #4
	bcs final_spin
	; State 3: wait for phase to fall below 20.
	lda phase+1
	cmp #20
	bcs done
	inc effect_state
	bra done
final_spin
	lda phase+1
	cmp #60
	bcs exit_effect
	cmp #46
	bcs small_boxes_black
	cmp #44
	bcs small_boxes_red_again
	bra done
small_boxes_red_again
	lda #0 ^ 7
	sta bg_colour
	lda #1 ^ 7
	sta small_box_colour
	jsr recolour_outside_boxes
	bra done
small_boxes_black
	lda #0 ^ 7
	sta bg_colour
	sta small_box_colour
	jsr recolour_outside_boxes
done:
	.)

finish_iteration
	jsr music_poll
	jmp effect_loop

exit_effect

	jsr deinit_effect
	jsr music_deinitialize
	jsr music_start_eventv

	lda #1
	jsr mos_setmode
	jsr mos_cursoroff

	jsr adding_colours

	; Copy the next effect from shadow RAM and then start it.
	lda #>[copper_size+255]
	jmp copy_effect_from_shadow
	
anim_ctr
	.byte 0

effect_state
	.byte 0

next_effect
	.asc "run copper",13
player
	.asc "player",13
copper_effect
	.asc "copper",13
final_pic
	.asc "owl3z",13
	
	.include "../lib/mos.s"
	.include "../lib/cmp.s"
	.include "../font/64font.s"
	.include "../lib/vgmentry.s"
	.include "../lib/load.s"
	.include "../lib/sram.s"
	.include "../lib/srambanks.s"
	.include "../copper/copper-size.s"
	.include "../finalpic/final-pic-size.s"
	
	.context set_mode_inf
	.var tmp
set_mode_inf
	ldx #0
loop
	lda setminf,x
	beq done
	jsr osasci
	inx
	bra loop
done:
	rts
setminf:
	.asc ">MODE /0",13,0
	.ctxend
	
	.context adding_colours
	.var tmp
adding_colours
	ldx #0
loop
	lda addcol,x
	beq done
	jsr osasci
	inx
	bra loop
done
	lda #200
	sta %tmp
wait:
	lda #19
	jsr osbyte
	dec %tmp
	bne wait
	rts
addcol
	.asc 13,13,"Enhancing graphics hardware...",13,13
	.asc "Please wait.",0
	.ctxend
	
	.context stripes
	.var2 ptr
	.var xpos
	.var stripecol
	.var block
stripes
	lda #<$3000
	sta %ptr
	lda #>$3000
	sta %ptr+1
	
	stz %xpos
	stz %stripecol
	stz %block
	
xloop
	lda %ptr
	sta %draw_column.column_top
	lda %ptr+1
	sta %draw_column.column_top+1
	lda %stripecol
	sta %draw_column.stripe_idx
	lda %block
	sta %draw_column.block_idx
	jsr draw_column
	
	lda %ptr
	clc
	adc #8
	sta %ptr
	.(
	bcc nohi
	inc %ptr+1
nohi:	.)

	.(
	inc %stripecol
	lda %stripecol
	cmp #15
	bne skip
	stz %stripecol
skip:	.)

	.(
	inc %block
	lda %block
	cmp #96
	bne skip
	stz %block
skip:	.)

	inc %xpos
	lda %xpos
	cmp #80
	bne xloop
	
	rts
	.ctxend
	
stripecolour
	.byte [0b0000000 << 1] | 0b0000001
	.byte [0b0000100 << 1] | 0b0000101
	.byte [0b0010000 << 1] | 0b0010001
	.byte [0b0010100 << 1] | 0b0010101
	.byte [0b1000000 << 1] | 0b1000001
	.byte [0b1000100 << 1] | 0b1000101
	.byte [0b1010000 << 1] | 0b1010001
	.byte [0b1010100 << 1] | 0b0000000
	.byte [0b0000001 << 1] | 0b0000100
	.byte [0b0000101 << 1] | 0b0010000
	.byte [0b0010001 << 1] | 0b0010100
	.byte [0b0010101 << 1] | 0b1000000
	.byte [0b1000001 << 1] | 0b1000100
	.byte [0b1000101 << 1] | 0b1010000
	.byte [0b1010001 << 1] | 0b1010100

	.context draw_column
	; args -- column_top is clobbered.
	.var2 column_top
	.var stripe_idx
	.var block_idx
	; locals
	.var stripecol
	.var blocknum
draw_column
	ldy %stripe_idx
	lda stripecolour,y
	sta %stripecol
	lda #32
	sta %blocknum
loop
	lda %block_idx
	and #16
	beq stripes
	lda %blocknum
	dec
	and #8
	beq stripes
solid
	lda #[0b1010101 << 1] | 0b1010101
	bra block
stripes
	lda %stripecol
block
	ldy #0 : sta (%column_top),y
	ldy #1 : sta (%column_top),y
	ldy #2 : sta (%column_top),y
	ldy #3 : sta (%column_top),y
	ldy #4 : sta (%column_top),y
	ldy #5 : sta (%column_top),y
	ldy #6 : sta (%column_top),y
	ldy #7 : sta (%column_top),y
	
	lda %column_top
	clc
	adc #<640
	sta %column_top
	lda %column_top+1
	adc #>640
	sta %column_top+1
	
	.(
	; lda %column_top+1
	cmp #$80
	bcc nowrap
	
	; lda %column_top+1
	clc
	adc #>[$3000-$8000]
	sta %column_top+1
	
nowrap:	.)

	dec %blocknum
	bne loop
	
	rts
	.ctxend

	.macro crtc_write addr data
	lda #%addr
	sta CRTC_ADDR
	lda %data
	sta CRTC_DATA
	.mend
	
start_addr
	.word $3000
	; These are the "next" columns to draw on the lhs/rhs, i.e. after
	; scrolling one column.
lhs_col
	.byte 14
rhs_col
	.byte 5
lhs_blk
	.byte 95
rhs_blk
	.byte 16
bglayer_offset
	.byte 0

	; Scroll screen contents to the left by AMOUNT, filling in columns on
	; the right-hand side.
	.context scroll_left
	; args. Clobbered.
	.var amount
	; temps
	.var2 tmp, rhs_col_addr
	.var tmp2, amount_copy

scroll_left:
	lda %amount
	sta %amount_copy
	; Set %tmp to amount * 8.
	stz %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	sta %tmp
		
	; The first column to fill is start_addr + 640. Set
	; %rhs_col_addr to this.
	lda start_addr
	clc
	adc #<640
	sta %rhs_col_addr
	lda start_addr+1
	adc #>640
	sta %rhs_col_addr+1
	
	cmp #$80
	bcc fill_rhs_cols
	
	; Perform wrap-around. We only need to touch the MSB.
	lda %rhs_col_addr+1
	clc
	adc #>[$3000-$8000]
	sta %rhs_col_addr+1
	
fill_rhs_cols
	lda %rhs_col_addr
	sta %draw_column.column_top
	lda %rhs_col_addr+1
	sta %draw_column.column_top+1
	lda rhs_col
	sta %draw_column.stripe_idx
	lda rhs_blk
	sta %draw_column.block_idx
	jsr draw_column
	
	; Update column address.
	lda %rhs_col_addr
	clc
	adc #8
	sta %rhs_col_addr
	.(
	lda %rhs_col_addr+1
	adc #0
	cmp #$80
	bcc nowrap
	clc
	adc #>[$3000-$8000]
nowrap:	.)
	sta %rhs_col_addr+1
	
	; Update lhs/rhs column indices.
	.(
	inc lhs_col
	lda lhs_col
	cmp #15
	bne skip
	stz lhs_col
skip:	.)

	.(
	inc rhs_col
	lda rhs_col
	cmp #15
	bne skip
	stz rhs_col
skip:	.)
	
	.(
	inc lhs_blk
	lda lhs_blk
	cmp #96
	bne skip
	stz lhs_blk
skip:	.)

	.(
	inc rhs_blk
	lda rhs_blk
	cmp #96
	bne skip
	stz rhs_blk
skip:	.)
	
	dec %amount
	bne fill_rhs_cols

	; Change the start address.	
	lda start_addr
	clc
	adc %tmp
	sta start_addr
	lda start_addr+1
	adc %tmp+1
	.(
	cmp #$80
	bcc nowrap
	clc
	adc #>[$3000-$8000]
nowrap:	.)
	sta start_addr+1

	.(
	lda bglayer_offset
	sec
	sbc %amount_copy
retry:
	cmp #15
	bcc skip
	clc
	adc #15
	bra retry
skip:	.)
	sta bglayer_offset

	rts
	.ctxend

	.context scroll_right
	; args. Clobbered.
	.var amount
	; temps
	.var2 tmp, lhs_col_addr
	.var amount_copy

scroll_right:
	lda %amount
	sta %amount_copy
	stz %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	sta %tmp
	
	; The first column to fill is start_addr - 8. Set %lhs_col_addr to this.
	lda start_addr
	sec
	sbc #8
	sta %lhs_col_addr
	lda start_addr+1
	sbc #0
	sta %lhs_col_addr+1
	
	cmp #$30
	bcs fill_lhs_cols
	
	; Perform wrap-around.
	clc
	adc #>[$8000-$3000]
	sta %lhs_col_addr+1

fill_lhs_cols
	lda %lhs_col_addr
	sta %draw_column.column_top
	lda %lhs_col_addr+1
	sta %draw_column.column_top+1
	lda lhs_col
	sta %draw_column.stripe_idx
	lda lhs_blk
	sta %draw_column.block_idx
	jsr draw_column
	
	; Update column address.
	lda %lhs_col_addr
	sec
	sbc #8
	sta %lhs_col_addr
	.(
	lda %lhs_col_addr+1
	sbc #0
	cmp #$30
	bcs nowrap
	clc
	adc #>[$8000-$3000]
nowrap:	.)
	sta %lhs_col_addr+1

	; Update lhs/rhs column indices.
	.(
	dec lhs_col
	lda lhs_col
	cmp #$ff
	bne skip
	lda #14
	sta lhs_col
skip:	.)

	.(
	dec rhs_col
	lda rhs_col
	cmp #$ff
	bne skip
	lda #14
	sta rhs_col
skip:	.)

	.(
	dec lhs_blk
	lda lhs_blk
	cmp #$ff
	bne skip
	lda #95
	sta lhs_blk
skip:	.)

	.(
	dec rhs_blk
	lda rhs_blk
	cmp #$ff
	bne skip
	lda #95
	sta rhs_blk
skip:	.)

	dec %amount
	bne fill_lhs_cols
	
	; Change the start address.
	lda start_addr
	sec
	sbc %tmp
	sta start_addr
	lda start_addr+1
	sbc %tmp+1
	.(
	cmp #$30
	bcs nowrap
	clc
	adc #>[$8000-$3000]
nowrap:	.)
	sta start_addr+1
	
	.(
	lda bglayer_offset
	clc
	adc %amount_copy
retry:
	cmp #15
	bcc skip
	sec
	sbc #15
	bra retry
skip:	.)
	sta bglayer_offset
	
	
	rts
	.ctxend

	; Update palette for BG layer by modifying code. Set to
	; "bglayer_offset".

	.macro horiz_scroll_bg_layer
	lda #<[inside_boxes+1]
	sta pal_ptr
	lda #>[inside_boxes+1]
	sta pal_ptr+1
	lda bglayer_offset
	sta offset
	ldy #0
loop
	lda offset
	cmp #8
	bcs outside
	lda (pal_ptr),y
	and #0b11110000
	ora small_box_colour
	sta (pal_ptr),y
	bra done
outside
	lda (pal_ptr),y
	and #0b11110000
	ora bg_colour
	sta (pal_ptr),y
done
	tya
	clc
	adc #5
	tay
	
	inc offset
	lda offset
	cmp #15
	bcc skip
	stz offset
skip:
	
	cpy #75
	bcc loop
	.mend

recolour_outside_boxes
	.(
	lda #<[outside_boxes+1]
	sta pal_ptr
	lda #>[outside_boxes+1]
	sta pal_ptr+1
	ldy #0
loop
	lda (pal_ptr),y
	and #0b11110000
	ora bg_colour
	sta (pal_ptr),y

	tya
	clc
	adc #5
	tay
	
	cpy #75
	bcc loop
	rts
	.)

recolour_big_boxes
	.(
	; Just using this as a random temp...
	sta pal_ptr
	lda outside_boxes+15*5+1
	and #0b11110000
	ora pal_ptr
	sta outside_boxes+15*5+1
	
	lda inside_boxes+15*5+1
	and #0b11110000
	ora pal_ptr
	sta inside_boxes+15*5+1
	rts
	.)

	; Called from IRQ, can't be context! Be careful with 'tmp' usage.
	.macro set_hwscroll

	; tmp3 = start_addr / 8
	lda start_addr+1
	sta tmp3+1
	lda start_addr
	lsr tmp3+1
	ror a
	lsr tmp3+1
	ror a
	lsr tmp3+1
	ror a
	sta tmp3
	
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
	
	; tmp += tmp2  (tmp = v_row * 80)
	lda tmp
	clc
	adc tmp2
	sta tmp
	lda tmp+1
	adc tmp2+1
	sta tmp+1
	
	lda #13
	sta CRTC_ADDR
	lda tmp
	clc
	adc tmp3
	sta CRTC_DATA
	lda #12
	sta CRTC_ADDR
	lda tmp+1
	adc tmp3+1
	cmp #$80/8
	bcc nowrap
	clc
	adc #>[[$3000-$8000]/8]
nowrap:
	sta CRTC_DATA
	.mend

msg_scrstart
	.word $6000 / 8

	.include "message.s"
;message
;	.byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
;	.byte 16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31
;	.byte 32,33,34,35,36,37,38,39
message_ptr
	.word 0
col_idx
	.byte 255
current_char_numcols
	.byte 0

	.context render_msg_column
	.var2 col_top, src_col, tmp
	.var2 message_tmp
render_msg_column
	sei
	lda ACCCON
	ora #4
	sta ACCCON
	cli
	
	lda msg_scrstart+1
	sta %col_top+1
	lda msg_scrstart
	asl a
	rol %col_top+1
	asl a
	rol %col_top+1
	asl a
	rol %col_top+1
	sta %col_top
		
	; column to write to on screen
	lda %col_top
	clc
	adc #<632
	sta %col_top
	lda %col_top+1
	adc #>632
	.(
	cmp #$80
	bcc nowrap
	clc
	adc #$60-$80
nowrap:	.)
	sta %col_top+1
	
	lda #<message
	clc
	adc message_ptr
	sta %message_tmp
	lda #>message
	adc message_ptr+1
	sta %message_tmp+1

	lda (%message_tmp)
	
	tax
	lda char_lens,x
	sta current_char_numcols

	lda char_starts,x
	clc
	adc #<char_columns
	sta %tmp
	lda #0
	adc #>char_columns
	sta %tmp+1
		
	; %tmp is now first index into column
	ldy col_idx
	cpy #255
	bne not_interchar_column
	; The space column.
	lda #63
	bra interchar_column
not_interchar_column
	lda (%tmp),y
	
interchar_column
	stz %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	asl a
	rol %tmp+1
	
	; %tmp now multiplied by 16 to find column index
	clc
	adc #<font_columns
	sta %src_col
	lda %tmp+1
	adc #>font_columns
	sta %src_col+1
	
	ldy #0 : lda (%src_col),y : sta (%col_top),y
	ldy #1 : lda (%src_col),y : sta (%col_top),y
	ldy #2 : lda (%src_col),y : sta (%col_top),y
	ldy #3 : lda (%src_col),y : sta (%col_top),y
	ldy #4 : lda (%src_col),y : sta (%col_top),y
	ldy #5 : lda (%src_col),y : sta (%col_top),y
	ldy #6 : lda (%src_col),y : sta (%col_top),y
	ldy #7 : lda (%src_col),y : sta (%col_top),y
	
	lda %col_top
	clc
	adc #<640
	sta %col_top
	lda %col_top+1
	adc #>640
	.(
	cmp #$80
	bcc nowrap
	clc
	adc #$60-$80
nowrap:	.)
	sta %col_top+1
	
	lda %src_col
	clc
	adc #8
	sta %src_col
	.(
	bcc nohi
	inc %src_col+1
nohi:	.)

	ldy #0 : lda (%src_col),y : sta (%col_top),y
	ldy #1 : lda (%src_col),y : sta (%col_top),y
	ldy #2 : lda (%src_col),y : sta (%col_top),y
	ldy #3 : lda (%src_col),y : sta (%col_top),y
	ldy #4 : lda (%src_col),y : sta (%col_top),y
	ldy #5 : lda (%src_col),y : sta (%col_top),y
	ldy #6 : lda (%src_col),y : sta (%col_top),y
	ldy #7 : lda (%src_col),y : sta (%col_top),y
	
	.(
	lda col_idx
	inc a
	cmp current_char_numcols
	bcc samechar
	
	.(
	inc message_ptr
	bne nohi
	inc message_ptr+1
nohi:	.)

	.(
	@if_ltu_imm message_ptr, message_length, not_end
	stz message_ptr
	stz message_ptr+1
not_end:
	.)
	
	lda #255
samechar
	sta col_idx
	.)
	
	sei
	lda ACCCON
	and #~4
	sta ACCCON
	cli

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
        
	lda USR_IER
	sta old_usr_ier
	
        ; Sys VIA CA1 interrupt
	lda SYS_PCR
	sta old_sys_pcr
	lda #4
        sta SYS_PCR

	; This removes jitters, but stops the keyboard from working!
	lda SYS_ACR
	sta old_sys_acr
	lda #0
	sta SYS_ACR

	;lda #15:sta SYS_DDRB
	;lda #4:sta SYS_ORB:inc a:sta SYS_ORB
	;lda #3:sta SYS_ORB
	;lda #$7f:sta SYS_DDRA

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

deinit_effect
	.(
	sei
	
	lda oldirq1v
	sta $204
	lda oldirq1v+1
	sta $205
	
	lda #$7f
	sta SYS_IER
	lda old_sys_ier
	sta SYS_IER
	
	lda old_sys_pcr
	sta SYS_PCR
	
	lda old_sys_acr
	sta SYS_ACR
	
	lda #<1000
	sta SYS_T1C_L
	lda #>1000
	sta SYS_T1C_H
	
	lda #<10000
	sta SYS_T1L_L
	lda #>10000
	sta SYS_T1L_H
	
	lda #$7f
	sta USR_IER
	lda old_usr_ier
	sta USR_IER
	
	@crtc_write 4, {#38}
	@crtc_write 5, {#0}
	@crtc_write 6, {#32}
	@crtc_write 7, {#34}
	@crtc_write 8, {#0b11000001}
	@crtc_write 12, {#>[$3000/8]}
	@crtc_write 13, {#<[$3000/8]}
	
	cli
	rts
	.)

v_offset
	.byte 0
v_offset_usr
	.byte 0

vpos
	.word 0
hpos
	.word 0
old_hpos
	.byte 0
phase
	.word 0
utmp
	.byte 0
vsync_ours
	.byte 0

sintab:
	.include "sintab.s"

old_sys_ier
	.byte 0
oldirq1v
	.word 0
old_sys_pcr
	.byte 0
old_sys_acr
	.byte 0
old_usr_ier
	.byte 0

	.alias SECOND_CYCLE_SETUP 0
	.alias INSIDE_BOXES 1
	.alias OUTSIDE_BOXES 2
	.alias DISABLE_VIDEO 3
	.alias ENABLE_VIDEO 4
	.alias FIRST_CYCLE_SETUP 5
	.alias MODE_SWITCH 6

action_num
	.byte 0

	.alias NUM_ACTIONS 24

	; These are preprocessed by action_diffs.
action_times
	.word 0
	.word 64*16-2
	.word 64*16*2-2
	.word 64*16*3-2
	.word 64*16*4-2
	.word 64*16*5-2
	.word 64*16*6-2
	.word 64*16*7-2
	.word 64*16*8-2
	.word 64*16*9-2
	.word 64*16*10-2
	.word 64*16*11-2
	.word 64*16*12-2
	.word 64*16*13-2
	.word 64*16*14-2
	.word 64*8*[top_screen_lines-1]
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0
	.word 0

final_action
	.word 64*8*[top_screen_lines-1] - 64*3
	.word 64*8*[top_screen_lines-1]
last_action

action_time_diffs
	.dsb NUM_ACTIONS*2,0

action_types
	.byte -1
	.byte FIRST_CYCLE_SETUP
	.byte INSIDE_BOXES
	.byte OUTSIDE_BOXES
	.byte INSIDE_BOXES
	.byte OUTSIDE_BOXES
	.byte INSIDE_BOXES
	.byte OUTSIDE_BOXES
	.byte INSIDE_BOXES
	.byte OUTSIDE_BOXES
	.byte INSIDE_BOXES
	.byte OUTSIDE_BOXES
	.byte INSIDE_BOXES
	.byte OUTSIDE_BOXES
	.byte INSIDE_BOXES
	.byte OUTSIDE_BOXES
	.byte SECOND_CYCLE_SETUP
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0

	.macro latch_action
	lda action_num
	asl a
	tay
	lda action_time_diffs,y
	sec
	sbc #2
	sta USR_T1L_L
	lda action_time_diffs+1,y
	sbc #0
	sta USR_T1L_H
	.mend
	
	.macro next_action
	inc action_num
	.mend

action_diffs
	.(
	ldx #0
	stx tmp
loop
	lda action_times+2,x
	sec
	sbc action_times,x
	sta action_time_diffs,x
	lda action_times+3,x
	sbc action_times+1,x
	sta action_time_diffs+1,x
	
	;lda action_time_diffs,x
	;sec
	;sbc #2
	;sta action_time_diffs,x
	;lda action_time_diffs+1,x
	;sbc #0
	;sta action_time_diffs+1,x
	
	inx : inx

	inc tmp
	lda tmp
	cmp #NUM_ACTIONS-1
	bne loop
	
	rts
	.)

flips_from_v_offset
	.(
	lda #<[action_times+2]
	sta tmp2
	lda #>[action_times+2]
	sta tmp2+1
	
	lda v_offset
	eor #$ff
	lsr a
	sta tmp3
	
	and #15
	stz tmp4
	lsr a
	ror tmp4
	lsr a
	ror tmp4
	sta tmp4+1

	lda tmp4
	clc
	adc #<[64*4]
	sta tmp4
	lda tmp4+1
	adc #>[64*4]
	sta tmp4+1

	lda tmp3
	and #16
	sta tmp3
	
	sta top_small_box_colour

	ldy #0
	ldx #0
fill:
	lda tmp4
	sta (tmp2),y
	iny
	lda tmp4+1
	sta (tmp2),y
		
	lda tmp4
	clc
	adc #<[64*4]
	sta tmp
	lda tmp4+1
	adc #>[64*4]
	sta tmp+1
	
	.(
	@if_ltu_abs tmp, final_action, ok
	dey
	lda final_action
	sta (tmp2),y
	iny
	lda final_action+1
	sta (tmp2),y
	lda #MODE_SWITCH
	sta action_types+2,x

	iny
	lda final_action+2
	sta (tmp2),y
	iny
	lda final_action+3
	sta (tmp2),y
	lda #SECOND_CYCLE_SETUP
	sta action_types+3,x

	bra exit
ok:	.)

	lda tmp4
	clc
	adc #<[64*16]
	sta tmp4
	lda tmp4+1
	adc #>[64*16]
	sta tmp4+1
	
	lda tmp3
	beq obox
	lda #INSIDE_BOXES
	bra store
obox
	lda #OUTSIDE_BOXES
store
	sta action_types+2,x
	
	lda tmp3
	eor #16
	sta tmp3
	
	inx
	
	iny
	cpy #32
	bne fill

exit
	rts
	.)

irq1:
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

	ldy action_num
	lda action_types,y
	asl a
	tax
	jmp (action_tab,x)

action_tab
	.word disable_irq
	.word inside_boxes
	.word outside_boxes
	.word disable_video
	.word enable_video
	.word first_after_vsync
	.word mode_switch
	
first_after_vsync	
	; First IRQ in the new CRTC cycle: set some registers
	; CRTC cycle length = 16 rows
	; Enable video
	@crtc_write 8, {#0b11000000}
	lda #5
	sta CRTC_ADDR
	lda v_offset
	and #7
	sta CRTC_DATA

	@crtc_write 4, {#top_screen_lines-2}
	@crtc_write 6, {#top_screen_lines}
	@crtc_write 7, {#255}

	@crtc_write 12, msg_scrstart+1
	@crtc_write 13, msg_scrstart

	;bra next_action_setup

	; At the top of the screen, we're either inside a small box or not.
	; set the palette right away.
	lda top_small_box_colour
	beq inside_boxes

	; WARNING: This label is used as an anchor to directly modify the
	; immediates in the subsequent code.
outside_boxes
	lda #0b00000111 ^ 1 : sta PALCONTROL
	lda #0b00010111 ^ 1 : sta PALCONTROL
	lda #0b00100111 ^ 1 : sta PALCONTROL
	lda #0b00110111 ^ 1 : sta PALCONTROL
	lda #0b01000111 ^ 1 : sta PALCONTROL
	lda #0b01010111 ^ 1 : sta PALCONTROL
	lda #0b01100111 ^ 1 : sta PALCONTROL
	lda #0b01110111 ^ 1 : sta PALCONTROL
	lda #0b10000111 ^ 1 : sta PALCONTROL
	lda #0b10010111 ^ 1 : sta PALCONTROL
	lda #0b10100111 ^ 1 : sta PALCONTROL
	lda #0b10110111 ^ 1 : sta PALCONTROL
	lda #0b11000111 ^ 1 : sta PALCONTROL
	lda #0b11010111 ^ 1 : sta PALCONTROL
	lda #0b11100111 ^ 1 : sta PALCONTROL
	lda #0b11110111 ^ 0 : sta PALCONTROL
	bra next_action_setup

	; WARNING: This one is too.
inside_boxes
	lda #0b00000111 ^ 3 : sta PALCONTROL
	lda #0b00010111 ^ 3 : sta PALCONTROL
	lda #0b00100111 ^ 3 : sta PALCONTROL
	lda #0b00110111 ^ 3 : sta PALCONTROL
	lda #0b01000111 ^ 3 : sta PALCONTROL
	lda #0b01010111 ^ 3 : sta PALCONTROL
	lda #0b01100111 ^ 3 : sta PALCONTROL
	lda #0b01110111 ^ 3 : sta PALCONTROL
	lda #0b10000111 ^ 1 : sta PALCONTROL
	lda #0b10010111 ^ 1 : sta PALCONTROL
	lda #0b10100111 ^ 1 : sta PALCONTROL
	lda #0b10110111 ^ 1 : sta PALCONTROL
	lda #0b11000111 ^ 1 : sta PALCONTROL
	lda #0b11010111 ^ 1 : sta PALCONTROL
	lda #0b11100111 ^ 1 : sta PALCONTROL
	lda #0b11110111 ^ 0 : sta PALCONTROL
	bra next_action_setup

mode_switch
	lda #0b11111000
	sta ULACONTROL
	lda #0b00000111 ^ 0 : sta PALCONTROL
	lda #0b00010111 ^ 0 : sta PALCONTROL
	lda #0b00100111 ^ 4 : sta PALCONTROL
	lda #0b00110111 ^ 4 : sta PALCONTROL
	lda #0b01000111 ^ 0 : sta PALCONTROL
	lda #0b01010111 ^ 0 : sta PALCONTROL
	lda #0b01100111 ^ 4 : sta PALCONTROL
	lda #0b01110111 ^ 4 : sta PALCONTROL
	lda #0b10000111 ^ 6 : sta PALCONTROL
	lda #0b10010111 ^ 6 : sta PALCONTROL
	lda #0b10100111 ^ 7 : sta PALCONTROL
	lda #0b10110111 ^ 7 : sta PALCONTROL
	lda #0b11000111 ^ 6 : sta PALCONTROL
	lda #0b11010111 ^ 6 : sta PALCONTROL
	lda #0b11100111 ^ 7 : sta PALCONTROL
	lda #0b11110111 ^ 7 : sta PALCONTROL
	lda ACCCON
	ora #1
	sta ACCCON

	bra next_action_setup

disable_video
	@crtc_write 8, {#0b11110000}
	bra next_action_setup

enable_video
	@crtc_write 8, {#0b11000000}

next_action_setup
	@latch_action
	@next_action
	bra exit_timer1

disable_irq
	; Disable usr timer1 interrupt
	lda #0b01000000
	sta USR_IER
	;lda #255
	;sta USR_T1C_L
	;sta USR_T1C_H
	
	; remaining rows
	@crtc_write 4, {#total_lines-top_screen_lines-1}
	;@crtc_write 6, {#displayed_lines-top_screen_lines}
	@crtc_write 6, {#2}
	;@crtc_write 7, {#total_lines-top_screen_lines-4}
	@crtc_write 7, {#4}

	;lda #0b00000111 ^ 6 : sta PALCONTROL
	;lda #0b00010111 ^ 6 : sta PALCONTROL
	;lda #0b00100111 ^ 6 : sta PALCONTROL
	;lda #0b00110111 ^ 6 : sta PALCONTROL
	;lda #0b01000111 ^ 6 : sta PALCONTROL
	;lda #0b01010111 ^ 6 : sta PALCONTROL
	;lda #0b01100111 ^ 6 : sta PALCONTROL
	;lda #0b01110111 ^ 4 : sta PALCONTROL
	;lda #0b10000111 ^ 4 : sta PALCONTROL
	;lda #0b10010111 ^ 4 : sta PALCONTROL
	;lda #0b10100111 ^ 4 : sta PALCONTROL
	;lda #0b10110111 ^ 4 : sta PALCONTROL
	;lda #0b11000111 ^ 4 : sta PALCONTROL
	;lda #0b11010111 ^ 4 : sta PALCONTROL
	;lda #0b11100111 ^ 4 : sta PALCONTROL
	;lda #0b11110111 ^ 0 : sta PALCONTROL

	; Set 8K screen RAM for hw scrolling.
	lda #15
	sta SYS_DDRB
	lda #0b1100
	sta SYS_ORB
	lda #0b0101
	sta SYS_ORB

exit_timer1:
	ply
	plx
	pla
	sta $fc
	rti

new_cycle_time
	.word 64*8*5 + 64*8 - 64*2 + 18

vsync_ctr
	.word 0

	; We control when vsync happens!
vsync
	; Clear interrupt
	lda USR_T1C_L

        ; Trigger after 'new_cycle_time' microseconds
        lda new_cycle_time
        sta USR_T1C_L
        lda new_cycle_time+1
        sta USR_T1C_H

	phx
	phy

	lda #0
	sta action_num

	jsr flips_from_v_offset
	jsr action_diffs

	; Latch the time for the subsequent flip -- the first action.
	@latch_action
	@next_action

	;lda #<[64*8*top_screen_lines-2]
	;sta USR_T1L_L
	;lda #>[64*8*top_screen_lines-2]
	;sta USR_T1L_H

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

	inc vsync_ctr
	.(
	bne nohi
	inc vsync_ctr+1
nohi:	.)
	
	lda v_offset_usr
	sta v_offset
	
	@horiz_scroll_bg_layer
	@set_hwscroll
	
	lda #5
	sta CRTC_ADDR
	lda v_offset
	and #7
	eor #7
	inc
	sta CRTC_DATA

	; Disable video
	@crtc_write 8, {#0b11110000}

	;lda #0b00000111 ^ 6 : sta PALCONTROL
	;lda #0b00010111 ^ 6 : sta PALCONTROL
	;lda #0b00100111 ^ 6 : sta PALCONTROL
	;lda #0b00110111 ^ 6 : sta PALCONTROL
	;lda #0b01000111 ^ 6 : sta PALCONTROL
	;lda #0b01010111 ^ 6 : sta PALCONTROL
	;lda #0b01100111 ^ 6 : sta PALCONTROL
	;lda #0b01110111 ^ 4 : sta PALCONTROL
	;lda #0b10000111 ^ 4 : sta PALCONTROL
	;lda #0b10010111 ^ 4 : sta PALCONTROL
	;lda #0b10100111 ^ 4 : sta PALCONTROL
	;lda #0b10110111 ^ 4 : sta PALCONTROL
	;lda #0b11000111 ^ 4 : sta PALCONTROL
	;lda #0b11010111 ^ 4 : sta PALCONTROL
	;lda #0b11100111 ^ 4 : sta PALCONTROL
	;lda #0b11110111 ^ 0 : sta PALCONTROL

	lda #0b11110100
	sta ULACONTROL
	lda ACCCON
	and #~1
	sta ACCCON

	; Set 20K screen ram for hw scrolling. Note the AUG has the wrong values
	; in the table for these!
	lda #15
	sta SYS_DDRB
	lda #0b0100
	sta SYS_ORB
	lda #0b1101
	sta SYS_ORB

	; gtfo
	ply
	plx
	pla
	sta $fc
	rti
	;jmp (oldirq1v)
