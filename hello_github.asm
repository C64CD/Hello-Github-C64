;
; HELLO GITHUB
;

; Code, graphics and music by TMR


; Notes: this source is formatted for the ACME cross assembler available
; from http://sourceforge.net/projects/acme-crossass/

; Everything is done before $2000 in memory, but $3fff is zeroed at the
; start of each frame so the border areas are clear apart from the
; hardware sprites.


; Memory Map
; $0801 - $0e3f		program code/data
; $0e40 - $0fff		sprites
; $1000 - $1bff		music
; $1c00 - $1fff		scrolling message


; Select an output filename
		!to "hello_github.prg",cbm


; Pull in the binary data
		* = $0e40
		!binary "binary\c64cd_sprites.raw"

		* = $1000
music		!binary "binary\hymn_to_yezz.prg",,2


; Raster split positions
raster_1_pos	= $00
raster_2_pos	= $f9

; Label assignments
raster_num	= $50
scroll_x	= $51
scroll_pos	= $52		; two bytes used

sine_at		= $54
scroll_colour	= $55

scroll_line	= $05e0
scroll_col_line	= scroll_line+$d400

; Add a BASIC startline
		* = $0801
		!word code_start-2
		!byte $40,$00,$9e
		!text "2066"
		!byte $00,$00,$00


; Entry point for the code
		* = $0812

; Stop interrupts, disable the ROMS and set up NMI and IRQ interrupt pointers
code_start	sei

		lda #$35
		sta $01

		lda #<nmi_int
		sta $fffa
		lda #>nmi_int
		sta $fffb

		lda #<irq_int
		sta $fffe
		lda #>irq_int
		sta $ffff

; Set the VIC-II up for a raster IRQ interrupt
		lda #$7f
		sta $dc0d
		sta $dd0d

		lda $dc0d
		lda $dd0d

		lda #raster_1_pos
		sta $d012

		lda #$1b
		sta $d011
		lda #$01
		sta $d019
		sta $d01a

; Initialise some of our own labels
		lda #$01
		sta raster_num
		lda #$00
		sta scroll_x

; Clear the screen RAM
		ldx #$00
		lda #$20
screen_clear	sta $0400,x
		sta $0500,x
		sta $0600,x
		sta $06e8,x
		inx
		bne screen_clear

; Reset the scroller
		jsr scroll_reset

; Set up the music driver
		lda #$00
		jsr music+$00


; Restart the interrupts
		cli

; Infinite loop - all of the code is executing on the interrupt
		jmp *


; IRQ interrupt handler
irq_int		pha
		txa
		pha
		tya
		pha

		lda $d019
		and #$01
		sta $d019
		bne int_go
		jmp irq_exit

; An interrupt has triggered
int_go		lda raster_num
		cmp #$02
		bne *+$05
		jmp irq_rout2


; Raster split 1
irq_rout1	lda #$0e
		sta $d020
		lda #$06
		sta $d021
		lda #$00
		sta $3fff

		lda scroll_x
		and #$03
		asl
		eor #$07
		sta $d016
		lda #$16
		sta $d018

; Set up the sprites
		lda #$ff
		sta $d015
		sta $d01b

		ldx #$00
		ldy #$00
set_sprite_x	lda sprite_x_pos,x
		sta $d000,y
		iny
		iny
		inx
		cpx #$08
		bne set_sprite_x
		lda sprite_x_msb
		sta $d010

		ldx #$00
		ldy sine_at
set_sprite_y	lda sprite_sinus,y
		sta $d001,x
		tya
		sec
		sbc #$0c
		cpx #$04
		bne *+$05
		sec
		sbc #$40
		tay
		inx
		inx
		cpx #$10
		bne set_sprite_y

		ldx #$00
		lda #$38
hide_sprite_dp	sta $07f8,x
		inx
		cpx #$08
		bne hide_sprite_dp

		lda #$1a
		cmp $d012
		bne *-$03

		ldx #$00
set_sprite_dp	lda sprite_dps,x
		sta $07f8,x
		lda sprite_colours,x
		sta $d027,x
		inx
		cpx #$08
		bne set_sprite_dp

; Play the music
		jsr music+$03

; Set interrupt handler for split 2
		lda #$02
		sta raster_num
		lda #raster_2_pos
		sta $d012

; Exit IRQ interrupt
		jmp irq_exit


; Raster split 2
irq_rout2

; Set interrupt handler for split 1
		lda #$01
		sta raster_num
		lda #raster_1_pos
		sta $d012


; Open the upper and lower borders
		lda #$14
		sta $d011

		lda #$fc
		cmp $d012
		bne *-$03
		lda #$1b
		sta $d011


; Move scrolling message
		ldx scroll_x
		inx
		cpx #$04
		bne scr_xb

; Move the text line
		ldx #$00
scroll_mover	lda scroll_line+$01,x
		sta scroll_line+$00,x
		lda scroll_col_line+$01,x
		sta scroll_col_line+$00,x
		inx
		cpx #$26
		bne scroll_mover

; Copy a new character to the scroller
		ldy #$00
scroll_mread	lda (scroll_pos),y
		bne scroll_okay
		jsr scroll_reset
		jmp scroll_mread

scroll_okay	cmp #$80
		bcc scroll_okay_2
		and #$0f
		sta scroll_colour
		lda #$20

scroll_okay_2	sta scroll_line+$26
		lda scroll_colour
		sta scroll_col_line+$26

; Nudge the scroller onto the next character
		inc scroll_pos+$00
		bne *+$04
		inc scroll_pos+$01

		ldx #$00
scr_xb		stx scroll_x


; Update the sprite movement
		inc sine_at


; Restore registers and exit IRQ interrupt
irq_exit	pla
		tay
		pla
		tax
		pla
nmi_int		rti


; Subroutine to reset the scrolling message
scroll_reset	lda #<scroll_text
		sta scroll_pos+$00
		lda #>scroll_text
		sta scroll_pos+$01
		rts


; Sprite data pointers and colours
sprite_x_pos	!byte $38,$54,$70,$ac,$c8,$e4,$00,$1c
sprite_x_msb	!byte $c0
sprite_dps	!byte $3d,$3b,$3c,$39,$3f,$3e,$39,$3a
sprite_colours	!byte $03,$03,$03,$0e,$0a,$0a,$0e,$0e


; Sprite movement sine table
sprite_sinus	!byte $8c,$8f,$91,$94,$96,$99,$9c,$9e
		!byte $a1,$a3,$a6,$a8,$ab,$ad,$b0,$b2
		!byte $b5,$b7,$b9,$bc,$be,$c0,$c3,$c5
		!byte $c7,$c9,$cb,$cd,$cf,$d1,$d3,$d5
		!byte $d7,$d9,$da,$dc,$de,$df,$e1,$e3
		!byte $e4,$e5,$e7,$e8,$e9,$ea,$ec,$ed
		!byte $ee,$ef,$f0,$f0,$f1,$f2,$f2,$f3
		!byte $f4,$f4,$f4,$f5,$f5,$f5,$f5,$f5

		!byte $f5,$f5,$f5,$f5,$f5,$f5,$f4,$f4
		!byte $f3,$f3,$f2,$f2,$f1,$f0,$ef,$ee
		!byte $ed,$ec,$eb,$ea,$e9,$e8,$e6,$e5
		!byte $e4,$e2,$e1,$df,$dd,$dc,$da,$d8
		!byte $d6,$d5,$d3,$d1,$cf,$cd,$cb,$c8
		!byte $c6,$c4,$c2,$c0,$bd,$bb,$b9,$b6
		!byte $b4,$b2,$af,$ad,$aa,$a8,$a5,$a3
		!byte $a0,$9d,$9b,$98,$96,$93,$91,$8e

		!byte $8b,$89,$86,$84,$81,$7e,$7c,$79
		!byte $77,$74,$72,$6f,$6d,$6a,$68,$65
		!byte $63,$60,$5e,$5c,$59,$57,$55,$53
		!byte $50,$4e,$4c,$4a,$48,$46,$44,$42
		!byte $40,$3f,$3d,$3b,$39,$38,$36,$35
		!byte $33,$32,$30,$2f,$2e,$2d,$2c,$2a
		!byte $29,$28,$28,$27,$26,$25,$25,$24
		!byte $23,$23,$23,$22,$22,$22,$22,$22

		!byte $22,$22,$22,$22,$22,$22,$23,$23
		!byte $24,$24,$25,$25,$26,$27,$28,$29
		!byte $2a,$2b,$2c,$2d,$2e,$2f,$31,$32
		!byte $34,$35,$37,$38,$3a,$3c,$3d,$3f
		!byte $41,$43,$45,$47,$49,$4b,$4d,$4f
		!byte $51,$53,$55,$58,$5a,$5c,$5f,$61
		!byte $63,$66,$68,$6b,$6d,$70,$72,$75
		!byte $77,$7a,$7c,$7f,$82,$84,$87,$89


; The all-important scrolling message - $00 wraps to the start and the
; values from $80 to $8f set the text colour
		* = $1c00
scroll_text	!byte $8f
		!scr "So",$87,"Github",$8f,"reckoned I should make a"
		!scr $81,$22,"Hello World",$22,$8f
		!scr "project to get things started, but I got carried away and "
		!scr "it accidentally turned into this little intro - "
		!scr "6K uncompressed with sprite movements, open borders, music "
		!scr "and still about 1K for scroll text!"
		!scr "      "

		!byte $88
		!scr "It has been, it should be noted, a"
		!scr $8a,"particularly",$88,"quiet Sunday...!"
		!scr "      "

		!byte $80
		!scr "Coding, sprites and music by ",$8e,"T.M.R",$80,"with the "
		!scr "latter being a conversion of the awesome"
		!scr $8e,$22,"Hymn To Yezz",$22
		!scr "      "

		!byte $85
		!scr "I'll just pause for a moment to plug the C64CD website at "
		!byte $8d
		!scr "C64CrapDebunk.Wordpress.com"
		!byte $85
		!scr "and that's pretty much everything said and done, so we "
		!scr "might as well wrap this scroller to the beginning..."
		!scr "          "

		!byte $00