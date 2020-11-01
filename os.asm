;;;;
; Nick Bild
; nick.bild@gmail.com
; November 2020
;
; Reserved memory:
;
; $0000-$7EFF - RAM
;     $0000 - byte send/received (keyboard)
;     $0001 - parity holder for rx (keyboard)
;     $0002 - ctrl, shift, caps and kb LED holder (keyboard)
;     $0003 - last byte received (keyboard)
; 		$0100-$01FF - 6502 stack
; $7F00 - Display Interrupt
; $7FE0-$7FEF - 6522 VIA (For keyboard input)
; $7FF0-$7FFF - 6522 VIA (For VGA display)
; $8000-$FFFF - ROM
; 		$FFFA-$FFFB - NMI IRQ Vector
; 		$FFFC-$FFFD - Reset Vector - Stores start address of this ROM.
; 		$FFFE-$FFFF - IRQ Vector
;
;;;;

		processor 6502

StartExe	ORG $8000
		sei

    ;;;;
    ;; Set up display VIA.
    ;;;;

		; Disable all VIA interrupts in IER.
		lda #$7F
		sta $7FFE

		; Set DDRB to all outputs.
		lda #$FF
		sta $7FF2

		; Set DDRA to all outputs.
		lda #$FF
		sta $7FF3

		; Set ORB outputs low.
		lda #$00
		sta $7FF0

		; Set ORA outputs low.
		lda #$00
		sta $7FF1

    ;;;;
    ;; Set up keyboad VIA.
    ;;;;

		; Disable all VIA interrupts in IER.
		lda #$7F
		sta $7FEE

		; Set DDRB to all outputs.
		lda #$FF
		sta $7FE2

		; Set DDRA to all outputs.
		lda #$FF
		sta $7FE3

		; Set ORB outputs low.
		lda #$00
		sta $7FE0

		; Set ORA outputs low.
		lda #$00
		sta $7FE1

    ; Init the keyboard, LEDs, and flags.
    jsr   kbinit

    ; cli

MainLoop
    lda #$08
    sta $7F00

		jmp MainLoop


; ~40ms @ 8MHz
Delay
		.byte #$DA ; phx
		.byte #$5A ; phy

		ldx #$FF
DelayLoop1	ldy #$FF
DelayLoop2	dey
		bne DelayLoop2
		dex
		bne DelayLoop1

		.byte #$7A ; ply
		.byte #$FA ; plx

		rts
