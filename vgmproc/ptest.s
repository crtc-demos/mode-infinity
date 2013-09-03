	.org $e05
	
	.alias player $2c00
	
	.alias initialize player
	.alias poll player+3
	.alias deinitialize player+6
	
start:
	jsr initialize
loop:
	jsr poll
	lda #19
	jsr osbyte
	bra loop
	
	jsr deinitialize
	
	rts

	.include "../lib/mos.s"
