	.org $e05
	
	.temps $70..$7f
	
	.alias total_lines 39
	.alias displayed_lines 32
	.alias top_screen_lines 30

	; These tmps are used from IRQ context. (FIXME: Pasta needs a way of
	; handling IRQ contexts properly.)
	.alias tmp $80
	.alias tmp2 $82
	.alias tmp3 $84
	.alias pal_ptr $86
	.alias offset $88
	
start:
	lda #2
	jsr mos_setmode
	jsr stripes
	jsr action_diffs
	jsr initvsync
	
scroll_loop
	lda #129
	ldx #<1000
	ldy #>1000
	jsr osbyte
	bcs scroll_loop
	cpx #'Q'
	beq spin
	cpx #'1'
	beq s1
	cpx #'2'
	beq s2
	cpx #'3'
	beq s3
	cpx #'7'
	beq l1
	cpx #'8'
	beq l2
	cpx #'9'
	beq l3
	bra scroll_loop
s1:	lda #1
	bra do_lscroll
s2:	lda #2
	bra do_lscroll
s3:	lda #3
do_lscroll
	sta %scroll_left.amount
	jsr scroll_left
	;jsr horiz_scroll_bg_layer
	bra scroll_loop

l1:	lda #1
	bra do_rscroll
l2:	lda #2
	bra do_rscroll
l3:	lda #3
do_rscroll:
	sta %scroll_right.amount
	jsr scroll_right
	;jsr horiz_scroll_bg_layer

	bra scroll_loop
	
spin
	;jmp spin
	rts
	
	.include "../lib/mos.s"
	.include "../lib/cmp.s"
	
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

horiz_scroll_bg_layer
	.(
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
	and #0b11111100
	sta (pal_ptr),y
	bra done
outside
	lda (pal_ptr),y
	ora #0b00000010
	sta (pal_ptr),y
done
	tya
	clc
	adc #5
	tay
	
	.(
	inc offset
	lda offset
	cmp #15
	bcc skip
	stz offset
skip:	.)
	
	cpy #75
	bcc loop
	rts
	.)

	; Called from IRQ, can't be context! Be careful with 'tmp' usage.
set_hwscroll:
	.(
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
	.(
	cmp #$80/8
	bcc nowrap
	clc
	adc #>[[$3000-$8000]/8]
nowrap:	.)
	sta CRTC_DATA
	
	rts
	.)

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

	.alias SECOND_CYCLE_SETUP 0
	.alias INSIDE_BOXES 1
	.alias OUTSIDE_BOXES 2
	.alias FIRST_CYCLE_SETUP 3

action_num
	.byte 0

	.alias MAX_ACTION 16

	; These are preprocessed by action_diffs.
action_times
	.word 0
	.word 64*15-2
	.word 64*15*2-2
	.word 64*15*3-2
	.word 64*15*4-2
	.word 64*15*5-2
	.word 64*15*6-2
	.word 64*15*7-2
	.word 64*15*8-2
	.word 64*15*9-2
	.word 64*15*10-2
	.word 64*15*11-2
	.word 64*15*12-2
	.word 64*15*13-2
	.word 64*15*14-2
	.word 64*15*15-2
	.word 64*8*top_screen_lines-2
last_action

action_time_diffs
	.dsb [MAX_ACTION+1]*2,0

action_types
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
	.byte INSIDE_BOXES
	.byte SECOND_CYCLE_SETUP

	.macro latch_action
	lda action_num
	asl a
	tay
	lda action_time_diffs,y
	sta USR_T1L_L
	iny
	lda action_time_diffs,y
	sta USR_T1L_H
	.mend
	
	.macro next_action
	inc action_num
	.mend

	.context action_diffs
	.var ctr
action_diffs
	ldx #0
	stx %ctr
	ldy #2
loop
	lda action_times,y
	sec
	sbc action_times,x
	sta action_time_diffs,x
	inx
	iny
	lda action_times,y
	sbc action_times,x
	sta action_time_diffs,x
	inx
	iny
	inc %ctr
	lda %ctr
	cmp #MAX_ACTION
	bne loop
	
	rts
	.ctxend

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

	lda first_after_vsync
	beq do_actions
	
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

	bra next_action_setup

do_actions
	ldy action_num
	@next_action
	lda action_types,y
	cmp #SECOND_CYCLE_SETUP
	beq disable_irq
	cmp #INSIDE_BOXES
	beq inside_boxes
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
	; WARNING: This label is used as an anchor to directly modify the
	; immediates in the subsequent code.
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

next_action_setup
	@latch_action
	bra exit_timer1

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

exit_timer1:
	ply
	plx
	pla
	sta $fc
	rti

new_cycle_time
	.word 64 * 40

first_after_vsync
	.byte 0

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

	lda #0
	sta action_num

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

	lda #1
	sta first_after_vsync

	inc v_offset

	;@crtc_write 12, {#>[$3000/8]}
	;@crtc_write 13, {#<[$3000/8]}
	
	
	;lda #13
	;sta CRTC_ADDR
	;lda #<[$3000/8]
	;clc
	;adc tmp
	;sta CRTC_DATA
	
	;lda #12
	;sta CRTC_ADDR
	;lda #>[$3000/8]
	;adc tmp+1
	;sta CRTC_DATA
	
	jsr horiz_scroll_bg_layer
	jsr set_hwscroll
	
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
