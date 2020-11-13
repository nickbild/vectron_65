;;;;
; Vectron 65 Operating System
;
; Nick Bild
; nick.bild@gmail.com
; November 2020
;
; Reserved memory:
;
; $0000-$7EFF - RAM
; 		$0000-$0006 - Named variables
;			$0020-$00D7 - Tiny Basic variables/config
; 		$0100-$01FF - 6502 stack
;     $0200-$5100 - Tiny Basic user program
;     $5101-$5130 - Display row 1
;     $5201-$5230 - Display row 2
;     $5301-$5330 - Display row 3
;     $5401-$5430 - Display row 4
;     $5501-$5530 - Display row 5
;     $5601-$5630 - Display row 6
;     $5701-$5730 - Display row 7
;     $5801-$5830 - Display row 8
;     $5901-$5930 - Display row 9
;     $5A01-$5A30 - Display row 10
;     $5B01-$5B30 - Display row 11
;     $5C01-$5C30 - Display row 12
;     $5D01-$5D30 - Display row 13
;     $5E01-$5E30 - Display row 14
;     $5F01-$5F30 - Display row 15
;     $6001-$6030 - Display row 16
;     $6101-$6130 - Display row 17
;     $6201-$6230 - Display row 18
;     $6301-$6330 - Display row 19
;     $6401-$6430 - Display row 20
;     $6501-$6530 - Display row 21
;     $6601-$6630 - Display row 22
;     $6701-$6730 - Display row 23
;     $6801-$6830 - Display row 24
;     $6901-$6930 - Display row 25
;     $6A01-$6A30 - Display row 26
;     $6B01-$6B30 - Display row 27
;     $6C01-$6C30 - Display row 28
; $7F00 - Display Interrupt
; $7FE0-$7FEF - 6522 VIA (For keyboard input)
; $7FF0-$7FFF - 6522 VIA (For VGA display)
; $8000-$FFFF - ROM
; 		$FFFA-$FFFB - NMI IRQ Vector
; 		$FFFC-$FFFD - Reset Vector - Stores start address of this ROM.
; 		$FFFE-$FFFF - IRQ Vector
;;;;

		processor 6502

		; Named variables in RAM.
		ORG $0000
; Keyboard
byte
		.byte #$00
parity
		.byte #$00
special
		.byte #$00
lastbyte
		.byte #$00
; Display
ScreenColumn
		.byte #$00
ScreenRow
		.byte #$00
Temp
		.byte #$00


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

		; Set DDRA to all outputs.
		lda #$FF
		sta $7FE3

		; Set ORA outputs low.
		lda #$00
		sta $7FE1

    ; Init the keyboard, LEDs, and flags.
    jsr   KBINIT

		; Set all screen memory to spaces (blank).
		jsr ClearScreenMemory

		; Set initial screen address.
		lda #$01
		sta ScreenColumn
		lda #$01
		sta ScreenRow

		lda ScreenRow
		sta $7FF0
		lda ScreenColumn
		sta $7FF1

    cli


; Start Tiny Basic.
FBLK     ldx #$00                   ; Offset for welcome message and prompt
         jsr SNDMSG                 ; Go print it
				 jmp COLD_S									; Cold start.


; Print the startup message.
SNDMSG   lda MBLK,X                 ; Get a character from the message block
         cmp #$FF                   ; Look for end of message marker
         beq EXSM                   ; Finish up if it is
         jsr SNDCHR                 ; Otherwise send the character
         inx                        ; Increment the pointer
         jmp SNDMSG                 ; Go get next character
EXSM     rts                        ; Return


; Tiny Basic keyboard input.
; Runs into SNDCHR for echo.
RCCHR
		jsr KBINPUT

		cmp #$0D				; Prevent double-CRs.
		bne EchoInput
		pha
		jmp NonPrintable
EchoInput

; Tiny Basic output.
SNDCHR
		pha

		; Is it backspace?
		cmp #$08
		bne NotBackSpace

		; Remove cursor.
		lda #$20
		sta $7F00

		dec ScreenColumn

		lda ScreenColumn
		cmp #$00
		bne SkipBackSpaceLineWrap
		lda ScreenRow
		cmp #$01
		beq BackSpaceRowOne
		; Move cursor to end of previous line.
		lda #$30
		sta ScreenColumn
		dec ScreenRow
		jmp SkipBackSpaceLineWrap
BackSpaceRowOne
		inc ScreenColumn
SkipBackSpaceLineWrap

		; Remove cursor.
		lda #$20
		sta $7F00

		; Set cursor address.
		lda ScreenRow
		sta $7FF0
		lda ScreenColumn
		sta $7FF1

		lda #$7F		; Cursor.
		sta $7F00		; Latch cursor to display.

		jmp NonPrintable
NotBackSpace

		; Control char?
		cmp #$0B
		bcc NonPrintable ; if < $0B, skip output.
		cmp #$0E
		beq NonPrintable
		cmp #$11
		beq NonPrintable
		cmp #$80
		beq NonPrintable
		cmp #$91
		beq NonPrintable
		cmp #$93
		beq NonPrintable
		cmp #$FF
		beq NonPrintable

		; Enter?
		cmp #$0D
		bne NotEnter
		; Remove cursor.
		lda #$20
		sta $7F00

		; Move to start of next line.
		lda #$01
		sta ScreenColumn
		inc ScreenRow

		lda ScreenRow
		cmp #$1D
		bne NoScreenScroll
		jsr ScrollScreenDataUp
		jsr RedrawScreen
		lda #$1C
		sta ScreenRow
NoScreenScroll

		; Set cursor address.
		lda ScreenRow
		sta $7FF0
		lda ScreenColumn
		sta $7FF1

		lda #$7F		; Cursor.
		sta $7F00		; Latch cursor to display.

		jmp NonPrintable
NotEnter

		sta $7F00		; Latch ASCII in A to display.
		sta Temp
		jsr SaveCharacter

		; Advance cursor and handle screen wrapping.
		inc ScreenColumn
		lda #$31
		cmp ScreenColumn
		bne NoLineWrap
		lda #$01
		sta ScreenColumn
		inc ScreenRow
NoLineWrap

		; Set cursor address.
		lda ScreenRow
		sta $7FF0
		lda ScreenColumn
		sta $7FF1

		lda #$7F		; Cursor.
		sta $7F00		; Latch cursor to display.

NonPrintable
		pla

		rts


; Tiny Basic break.
BREAK
		clc		; Never break.

		rts


; Set all pins in port A low on keyboard VIA.
KbViaPaLow
		lda #$00
		sta $7FE1
		rts


; Set all pins in port A high on keyboard VIA.
KbViaPaHigh
		lda #$FF
		sta $7FE1
		rts


; Stored typed character in RAM.
SaveCharacter
		lda ScreenRow
		ldx ScreenColumn

		; Row 1
		cmp #$01
		bne NotRow1
		lda Temp
		sta $5100,x
		jmp DoneSavingCharacter
NotRow1

		; Row 2
		cmp #$02
		bne NotRow2
		lda Temp
		sta $5200,x
		jmp DoneSavingCharacter
NotRow2

		; Row 3
		cmp #$03
		bne NotRow3
		lda Temp
		sta $5300,x
		jmp DoneSavingCharacter
NotRow3

		; Row 4
		cmp #$04
		bne NotRow4
		lda Temp
		sta $5400,x
		jmp DoneSavingCharacter
NotRow4

		; Row 5
		cmp #$05
		bne NotRow5
		lda Temp
		sta $5500,x
		jmp DoneSavingCharacter
NotRow5

		; Row 6
		cmp #$06
		bne NotRow6
		lda Temp
		sta $5600,x
		jmp DoneSavingCharacter
NotRow6

		; Row 7
		cmp #$07
		bne NotRow7
		lda Temp
		sta $5700,x
		jmp DoneSavingCharacter
NotRow7

		; Row 8
		cmp #$08
		bne NotRow8
		lda Temp
		sta $5800,x
		jmp DoneSavingCharacter
NotRow8

		; Row 9
		cmp #$09
		bne NotRow9
		lda Temp
		sta $5900,x
		jmp DoneSavingCharacter
NotRow9

		; Row 10
		cmp #$0A
		bne NotRow10
		lda Temp
		sta $5A00,x
		jmp DoneSavingCharacter
NotRow10

		; Row 11
		cmp #$0B
		bne NotRow11
		lda Temp
		sta $5B00,x
		jmp DoneSavingCharacter
NotRow11

		; Row 12
		cmp #$0C
		bne NotRow12
		lda Temp
		sta $5C00,x
		jmp DoneSavingCharacter
NotRow12

		; Row 13
		cmp #$0D
		bne NotRow13
		lda Temp
		sta $5D00,x
		jmp DoneSavingCharacter
NotRow13

		; Row 14
		cmp #$0E
		bne NotRow14
		lda Temp
		sta $5E00,x
		jmp DoneSavingCharacter
NotRow14

		; Row 15
		cmp #$0F
		bne NotRow15
		lda Temp
		sta $5F00,x
		jmp DoneSavingCharacter
NotRow15

		; Row 16
		cmp #$10
		bne NotRow16
		lda Temp
		sta $6000,x
		jmp DoneSavingCharacter
NotRow16

		; Row 17
		cmp #$11
		bne NotRow17
		lda Temp
		sta $6100,x
		jmp DoneSavingCharacter
NotRow17

		; Row 18
		cmp #$12
		bne NotRow18
		lda Temp
		sta $6200,x
		jmp DoneSavingCharacter
NotRow18

		; Row 19
		cmp #$13
		bne NotRow19
		lda Temp
		sta $6300,x
		jmp DoneSavingCharacter
NotRow19

		; Row 20
		cmp #$14
		bne NotRow20
		lda Temp
		sta $6400,x
		jmp DoneSavingCharacter
NotRow20

		; Row 21
		cmp #$15
		bne NotRow21
		lda Temp
		sta $6500,x
		jmp DoneSavingCharacter
NotRow21

		; Row 22
		cmp #$16
		bne NotRow22
		lda Temp
		sta $6600,x
		jmp DoneSavingCharacter
NotRow22

		; Row 23
		cmp #$17
		bne NotRow23
		lda Temp
		sta $6700,x
		jmp DoneSavingCharacter
NotRow23

		; Row 24
		cmp #$18
		bne NotRow24
		lda Temp
		sta $6800,x
		jmp DoneSavingCharacter
NotRow24

		; Row 25
		cmp #$19
		bne NotRow25
		lda Temp
		sta $6900,x
		jmp DoneSavingCharacter
NotRow25

		; Row 26
		cmp #$1A
		bne NotRow26
		lda Temp
		sta $6A00,x
		jmp DoneSavingCharacter
NotRow26

		; Row 27
		cmp #$1B
		bne NotRow27
		lda Temp
		sta $6B00,x
		jmp DoneSavingCharacter
NotRow27

		; Row 28
		cmp #$1C
		bne NotRow28
		lda Temp
		sta $6C00,x
		jmp DoneSavingCharacter
NotRow28

DoneSavingCharacter
		rts


; Scroll stored screen data up by 1 row.
ScrollScreenDataUp
		ldx #$30
Row2to1
		lda $5200,x
		sta $5100,x
		dex
		bne Row2to1

		ldx #$30
Row3to2
		lda $5300,x
		sta $5200,x
		dex
		bne Row3to2

		ldx #$30
Row4to3
		lda $5400,x
		sta $5300,x
		dex
		bne Row4to3

		ldx #$30
Row5to4
		lda $5500,x
		sta $5400,x
		dex
		bne Row5to4

		ldx #$30
Row6to5
		lda $5600,x
		sta $5500,x
		dex
		bne Row6to5

		ldx #$30
Row7to6
		lda $5700,x
		sta $5600,x
		dex
		bne Row7to6

		ldx #$30
Row8to7
		lda $5800,x
		sta $5700,x
		dex
		bne Row8to7

		ldx #$30
Row9to8
		lda $5900,x
		sta $5800,x
		dex
		bne Row9to8

		ldx #$30
Row10to9
		lda $5A00,x
		sta $5900,x
		dex
		bne Row10to9

		ldx #$30
Row11to10
		lda $5B00,x
		sta $5A00,x
		dex
		bne Row11to10

		ldx #$30
Row12to11
		lda $5C00,x
		sta $5B00,x
		dex
		bne Row12to11

		ldx #$30
Row13to12
		lda $5D00,x
		sta $5C00,x
		dex
		bne Row13to12

		ldx #$30
Row14to13
		lda $5E00,x
		sta $5D00,x
		dex
		bne Row14to13

		ldx #$30
Row15to14
		lda $5F00,x
		sta $5E00,x
		dex
		bne Row15to14

		ldx #$30
Row16to15
		lda $6000,x
		sta $5F00,x
		dex
		bne Row16to15

		ldx #$30
Row17to16
		lda $6100,x
		sta $6000,x
		dex
		bne Row17to16

		ldx #$30
Row18to17
		lda $6200,x
		sta $6100,x
		dex
		bne Row18to17

		ldx #$30
Row19to18
		lda $6300,x
		sta $6200,x
		dex
		bne Row19to18

		ldx #$30
Row20to19
		lda $6400,x
		sta $6300,x
		dex
		bne Row20to19

		ldx #$30
Row21to20
		lda $6500,x
		sta $6400,x
		dex
		bne Row21to20

		ldx #$30
Row22to21
		lda $6600,x
		sta $6500,x
		dex
		bne Row22to21

		ldx #$30
Row23to22
		lda $6700,x
		sta $6600,x
		dex
		bne Row23to22

		ldx #$30
Row24to23
		lda $6800,x
		sta $6700,x
		dex
		bne Row24to23

		ldx #$30
Row25to24
		lda $6900,x
		sta $6800,x
		dex
		bne Row25to24

		ldx #$30
Row26to25
		lda $6A00,x
		sta $6900,x
		dex
		bne Row26to25

		ldx #$30
Row27to26
		lda $6B00,x
		sta $6A00,x
		dex
		bne Row27to26

		ldx #$30
Row28to27
		lda $6C00,x
		sta $6B00,x
		dex
		bne Row28to27

		lda #$20 ; Space
		ldx #$30
Clear28
		sta $6C00,x
		dex
		bne Clear28

		rts


; Set all screen memory positions to space (blank).
ClearScreenMemory
		lda #$20 ; Space

		ldx #$30
ClearScreen1
		sta $5100,x
		dex
		bne ClearScreen1

		ldx #$30
ClearScreen2
		sta $5200,x
		dex
		bne ClearScreen2

		ldx #$30
ClearScreen3
		sta $5300,x
		dex
		bne ClearScreen3

		ldx #$30
ClearScreen4
		sta $5400,x
		dex
		bne ClearScreen4

		ldx #$30
ClearScreen5
		sta $5500,x
		dex
		bne ClearScreen5

		ldx #$30
ClearScreen6
		sta $5600,x
		dex
		bne ClearScreen6

		ldx #$30
ClearScreen7
		sta $5700,x
		dex
		bne ClearScreen7

		ldx #$30
ClearScreen8
		sta $5800,x
		dex
		bne ClearScreen8

		ldx #$30
ClearScreen9
		sta $5900,x
		dex
		bne ClearScreen9

		ldx #$30
ClearScreen10
		sta $5A00,x
		dex
		bne ClearScreen10

		ldx #$30
ClearScreen11
		sta $5B00,x
		dex
		bne ClearScreen11

		ldx #$30
ClearScreen12
		sta $5C00,x
		dex
		bne ClearScreen12

		ldx #$30
ClearScreen13
		sta $5D00,x
		dex
		bne ClearScreen13

		ldx #$30
ClearScreen14
		sta $5E00,x
		dex
		bne ClearScreen14

		ldx #$30
ClearScreen15
		sta $5F00,x
		dex
		bne ClearScreen15

		ldx #$30
ClearScreen16
		sta $6000,x
		dex
		bne ClearScreen16

		ldx #$30
ClearScreen17
		sta $6100,x
		dex
		bne ClearScreen17

		ldx #$30
ClearScreen18
		sta $6200,x
		dex
		bne ClearScreen18

		ldx #$30
ClearScreen19
		sta $6300,x
		dex
		bne ClearScreen19

		ldx #$30
ClearScreen20
		sta $6400,x
		dex
		bne ClearScreen20

		ldx #$30
ClearScreen21
		sta $6500,x
		dex
		bne ClearScreen21

		ldx #$30
ClearScreen22
		sta $6600,x
		dex
		bne ClearScreen22

		ldx #$30
ClearScreen23
		sta $6700,x
		dex
		bne ClearScreen23

		ldx #$30
ClearScreen24
		sta $6800,x
		dex
		bne ClearScreen24

		ldx #$30
ClearScreen25
		sta $6900,x
		dex
		bne ClearScreen25

		ldx #$30
ClearScreen26
		sta $6A00,x
		dex
		bne ClearScreen26

		ldx #$30
ClearScreen27
		sta $6B00,x
		dex
		bne ClearScreen27

		ldx #$30
ClearScreen28
		sta $6C00,x
		dex
		bne ClearScreen28

		rts


; Redraw entire display from screen memory.
RedrawScreen
		lda #$01
		sta $7FF0
		ldx #$30
RedrawRow1
		stx $7FF1
		lda $5100,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow1

		lda #$02
		sta $7FF0
		ldx #$30
RedrawRow2
		stx $7FF1
		lda $5200,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow2

		lda #$03
		sta $7FF0
		ldx #$30
RedrawRow3
		stx $7FF1
		lda $5300,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow3

		lda #$04
		sta $7FF0
		ldx #$30
RedrawRow4
		stx $7FF1
		lda $5400,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow4

		lda #$05
		sta $7FF0
		ldx #$30
RedrawRow5
		stx $7FF1
		lda $5500,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow5

		lda #$06
		sta $7FF0
		ldx #$30
RedrawRow6
		stx $7FF1
		lda $5600,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow6

		lda #$07
		sta $7FF0
		ldx #$30
RedrawRow7
		stx $7FF1
		lda $5700,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow7

		lda #$08
		sta $7FF0
		ldx #$30
RedrawRow8
		stx $7FF1
		lda $5800,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow8

		lda #$09
		sta $7FF0
		ldx #$30
RedrawRow9
		stx $7FF1
		lda $5900,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow9

		lda #$0A
		sta $7FF0
		ldx #$30
RedrawRow10
		stx $7FF1
		lda $5A00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow10

		lda #$0B
		sta $7FF0
		ldx #$30
RedrawRow11
		stx $7FF1
		lda $5B00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow11

		lda #$0C
		sta $7FF0
		ldx #$30
RedrawRow12
		stx $7FF1
		lda $5C00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow12

		lda #$0D
		sta $7FF0
		ldx #$30
RedrawRow13
		stx $7FF1
		lda $5D00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow13

		lda #$0E
		sta $7FF0
		ldx #$30
RedrawRow14
		stx $7FF1
		lda $5E00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow14

		lda #$0F
		sta $7FF0
		ldx #$30
RedrawRow15
		stx $7FF1
		lda $5F00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow15

		lda #$10
		sta $7FF0
		ldx #$30
RedrawRow16
		stx $7FF1
		lda $6000,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow16

		lda #$11
		sta $7FF0
		ldx #$30
RedrawRow17
		stx $7FF1
		lda $6100,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow17

		lda #$12
		sta $7FF0
		ldx #$30
RedrawRow18
		stx $7FF1
		lda $6200,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow18

		lda #$13
		sta $7FF0
		ldx #$30
RedrawRow19
		stx $7FF1
		lda $6300,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow19

		lda #$14
		sta $7FF0
		ldx #$30
RedrawRow20
		stx $7FF1
		lda $6400,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow20

		lda #$15
		sta $7FF0
		ldx #$30
RedrawRow21
		stx $7FF1
		lda $6500,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow21

		lda #$16
		sta $7FF0
		ldx #$30
RedrawRow22
		stx $7FF1
		lda $6600,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow22

		lda #$17
		sta $7FF0
		ldx #$30
RedrawRow23
		stx $7FF1
		lda $6700,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow23

		lda #$18
		sta $7FF0
		ldx #$30
RedrawRow24
		stx $7FF1
		lda $6800,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow24

		lda #$19
		sta $7FF0
		ldx #$30
RedrawRow25
		stx $7FF1
		lda $6900,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow25

		lda #$1A
		sta $7FF0
		ldx #$30
RedrawRow26
		stx $7FF1
		lda $6A00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow26

		lda #$1B
		sta $7FF0
		ldx #$30
RedrawRow27
		stx $7FF1
		lda $6B00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow27

		lda #$1C
		sta $7FF0
		ldx #$30
RedrawRow28
		stx $7FF1
		lda $6C00,x
		sta $7F00		; Latch ASCII in A to display.
		dex
		bne RedrawRow28

		rts


;;;;
;; Keyboard Routines
;; Daryl Rictor's freeware, modified by Nick Bild for
;; assembly with DASM.
;;;;

;****************************************************************************
; PC keyboard Interface for the 6502 Microprocessor utilizing a 6522 VIA
; (or suitable substitute)
;
; Designed and Written by Daryl Rictor (c) 2001   65c02@altavista.com
; Offered as freeware.  No warranty is given.  Use at your own risk.
;
; Software requires about 930 bytes of RAM or ROM for code storage and only 4 bytes
; in RAM for temporary storage.  Zero page locations can be used but are NOT required.
;
; Hardware utilizes any two bidirection IO bits from a 6522 VIA connected directly
; to a 5-pin DIN socket (or 6 pin PS2 DIN).  In this example I'm using the
; 6526 PB4 (Clk) & PB5 (Data) pins connected to a 5-pin DIN.  The code could be
; rewritten to support other IO arrangements as well.
; ________________________________________________________________________________
;|                                                                                |
;|        6502 <-> PC Keyboard Interface Schematic  by Daryl Rictor (c) 2001      |
;|                                                     65c02@altavista.com        |
;|                                                                                |
;|                                                           __________           |
;|                      ____________________________________|          |          |
;|                     /        Keyboard Data            15 |PB5       |          |
;|                     |                                    |          |          |
;|                _____|_____                               |          |          |
;|               /     |     \                              |   6522   |          |
;|              /      o      \    +5vdc (300mA)            |   VIA    |          |
;|        /-------o    2    o--------------------o---->     |          |          |
;|        |   |    4       5    |                |          |          |          |
;|        |   |                 |          *C1 __|__        |          |          |
;|        |   |  o 1       3 o  |              _____        |          |          |
;|        |   |  |              |                |          |          |          |
;|        |    \ |             /               __|__        |          |          |
;|        |     \|     _      /                 ___         |          |          |
;|        |      |____| |____/                   -          |          |          |
;|        |      |                  *C1 0.1uF Bypass Cap    |          |          |
;|        |      |                                          |          |          |
;|        |      \__________________________________________|          |          |
;|        |                    Keyboard Clock            14 | PB4      |          |
;|      __|__                                               |__________|          |
;|       ___                                                                      |
;|        -                                                                       |
;|            Keyboard Socket (not the keyboard cable)                            |
;|       (As viewed facing the holes)                                             |
;|                                                                                |
;|________________________________________________________________________________|
;
; Software communicates to/from the keyboard and converts the received scan-codes
; into usable ASCII code.  ASCII codes 01-7F are decoded as well as extra
; pseudo-codes in order to acess all the extra keys including cursor, num pad, function,
; and 3 windows 98 keys.  It was tested on two inexpensive keyboards with no errors.
; Just in case, though, I've coded the <Ctrl>-<Print Screen> key combination to perform
; a keyboard re-initialization just in case it goes south during data entry.
;
; Recommended Routines callable from external programs
;
; KBINPUT - wait for a key press and return with its assigned ASCII code in A.
; KBGET   - wait for a key press and return with its unprocessed scancode in A.
; KBSCAN  - Scan the keyboard for 105uS, returns 0 in A if no key pressed.
;           Return ambiguous data in A if key is pressed.  Use KBINPUT OR KBGET
;           to get the key information.  You can modify the code to automatically
;           jump to either routine if your application needs it.
; KBINIT  - Initialize the keyboard and associated variables and set the LEDs
;
;****************************************************************************
;
; All standard keys and control keys are decoded to 7 bit (bit 7=0) standard ASCII.
; Control key note: It is being assumed that if you hold down the ctrl key,
; you are going to press an alpha key (A-Z) with it (except break key defined below.)
; If you press another key, its ascii code's lower 5 bits will be send as a control
; code.  For example, Ctrl-1 sends $11, Ctrl-; sends $2B (Esc), Ctrl-F1 sends $01.
;
; The following no-standard keys are decoded with bit 7=1, bit 6=0 if not shifted,
; bit 6=1 if shifted, and bits 0-5 identify the key.
;
; Function key translation:
;              ASCII / Shifted ASCII
;            F1 - 81 / C1
;            F2 - 82 / C2
;            F3 - 83 / C3
;            F4 - 84 / C4
;            F5 - 85 / C5
;            F6 - 86 / C6
;            F7 - 87 / C7
;            F8 - 88 / C8
;            F9 - 89 / C9
;           F10 - 8A / CA
;           F11 - 8B / CB
;           F12 - 8C / CC
;
; The Print screen and Pause/Break keys are decoded as:
;                ASCII  Shifted ASCII
;        PrtScn - 8F       CF
;   Ctrl-PrtScn - performs keyboard reinitialization in case of errors
;                (haven't had any yet)  (can be removed or changed by user)
;     Pause/Brk - 03       03  (Ctrl-C) (can change to 8E/CE)(non-repeating key)
;    Ctrl-Break - 02       02  (Ctrl-B) (can be changed to AE/EE)(non-repeating key)
;      Scrl Lck - 8D       CD
;
; The Alt key is decoded as a hold down (like shift and ctrl) but does not
; alter the ASCII code of the key(s) that follow.  Rather, it sends
; a Alt key-down code and a seperate Alt key-up code.  The user program
; will have to keep track of it if they want to use Alt keys.
;
;      Alt down - A0
;        Alt up - E0
;
; Example byte stream of the Alt-F1 sequence:  A0 81 E0.  If Alt is held down longer
; than the repeat delay, a series of A0's will preceeed the 81 E0.
; i.e. A0 A0 A0 A0 A0 A0 81 E0.
;
; The three windows 98 keys are decoded as follows:
;                           ASCII    Shifted ASCII
;        Left Menu Key -      A1          E1
;       Right Menu Key -      A2          E2
;     Right option Key -      A3          E3
;
; The following "special" keys ignore the shift key and return their special key code
; when numlock is off or their direct labeled key is pressed.  When numlock is on, the digits
; are returned reguardless of shift key state.
; keypad(NumLck off) or Direct - ASCII    Keypad(NumLck on) ASCII
;          Keypad 0        Ins - 90                 30
;          Keypad .        Del - 7F                 2E
;          Keypad 7       Home - 97                 37
;          Keypad 1        End - 91                 31
;          Keypad 9       PgUp - 99                 39
;          Keypad 3       PgDn - 93                 33
;          Keypad 8    UpArrow - 98                 38
;          Keypad 2    DnArrow - 92                 32
;          Keypad 4    LfArrow - 94                 34
;          Keypad 6    RtArrow - 96                 36
;          Keypad 5    (blank) - 95                 35
;
;****************************************************************************
;
; I/O Port definitions

kbportreg      =     $7FE0             ; 6522 IO port register B
kbportddr      =     $7FE2             ; 6522 IO data direction register B
clk            =     $10               ; 6522 IO port clock bit mask (PB4)
data           =     $20               ; 6522 IO port data bit mask  (PB5)

; NOTE: some locations use the inverse of the bit masks to change the state of
; bit.  You will have to find them and change them in the code acordingly.
; To make this easier, I've placed this text in the comment of each such statement:
; "(change if port bits change)"
;
;
; temportary storage locations (zero page can be used but not necessary)

; byte           =     $0000             ; byte send/received
; parity         =     $0001             ; parity holder for rx
; special        =     $0002             ; ctrl, shift, caps and kb LED holder
; lastbyte       =     $0003             ; last byte received

; bit definitions for the special variable
; (1 is active, 0 inactive)
; special =  01 - Scroll Lock
;            02 - Num Lock
;            04 - Caps lock
;            08 - control (either left or right)
;            10 - shift  (either left or right)
;
;            Scroll Lock LED is used to tell when ready for input
;                Scroll Lock LED on  = Not ready for input
;                Scroll Lock LED off = Waiting (ready) for input
;
;            Num Lock and Caps Lock LED's are used normally to
;            indicate their respective states.
;
;***************************************************************************************
;
; test program - reads input, prints the ascii code to the terminal and loops until the
; target keyboard <Esc> key is pressed.
;
; external routine "output" prints character in A to the terminal
; external routine "print1byte" prints A register as two hexidecimal characters
; external routine "print_cr" prints characters $0D & $0A to the terminal
; (substitute your own routines as needed)
;
;               *=    $1000             ; locate program beginning at $1000
;               jsr   kbinit            ; init the keyboard, LEDs, and flags
;lp0            jsr   print_cr          ; prints 0D 0A (CR LF) to the terminal
;lp1            jsr   kbinput           ; wait for a keypress, return decoded ASCII code in A
;               cmp   #$0d              ; if CR, then print CR LF to terminal
;               beq   lp0               ;
;               cmp   #$1B              ; esc ascii code
;               beq   lp2               ;
;               cmp   #$20              ;
;               bcc   lp3               ; control key, print as <hh> except $0d (CR) & $2B (Esc)
;               cmp   #$80              ;
;               bcs   lp3               ; extended key, just print the hex ascii code as <hh>
;               jsr   output            ; prints contents of A reg to the Terminal, ascii 20-7F
;               bra   lp1               ;
;lp2            rts                     ; done
;lp3            pha                     ;
;               lda   #$3C              ; <
;               jsr   output            ;
;               pla                     ;
;               jsr   print1byte        ; print 1 byte in ascii hex
;               lda   #$3E              ; >
;               jsr   output            ;
;               bra   lp1               ;
;
;**************************************************************************************
;
; Decoding routines
;
; KBINPUT is the main routine to call to get an ascii char from the keyboard
; (waits for a non-zero ascii code)
;

;               *=    $7000             ; place decoder @ $7000

kbreinit       jsr   KBINIT            ;
KBINPUT        jsr   kbtscrl           ; turn off scroll lock (ready to input)
               bne   KBINPUT           ; ensure its off
kbinput1       jsr   KBGET             ; get a code (wait for a key to be pressed)
               jsr   kbcsrch           ; scan for 14 special case codes
kbcnvt         beq   kbinput1          ; 0=complete, get next scancode
               tax                     ; set up scancode as table pointer
               cmp   #$78              ; see if its the F11
               beq   kbcnvt1           ; it is, skip keypad test
               cmp   #$69              ; test for keypad codes 69
               bmi   kbcnvt1           ; thru
               cmp   #$7E              ; 7D (except 78 tested above)
               bpl   kbcnvt1           ; skip if not a keypad code
               lda   special           ; test numlock
               .byte #$89 ; bit #
							 .byte #$02              ; numlock on?
               beq   kbcnvt2           ; no, set shifted table for special keys
               txa                     ; yes, set unshifted table for number keys
               and   #$7F              ;
               tax                     ;
               jmp   kbcnvt3           ; skip shift test
kbcnvt1        lda   special           ;
               .byte #$89 ; bit #
							 .byte #$10              ; shift enabled?
               beq   kbcnvt3           ; no
kbcnvt2        txa                     ; yes
               ora   #$80              ; set shifted table
               tax                     ;
kbcnvt3        lda   special           ;
               .byte #$89 ; bit #
							 .byte #$08              ; control?
               beq   kbcnvt4           ; no
               lda   ASCIITBL,x        ; get ascii code
               cmp   #$8F              ; {ctrl-Printscrn - do re-init or user can remove this code }
               beq   kbreinit          ; {do kb reinit                                             }
               and   #$1F              ; mask control code (assumes A-Z is pressed)
               beq   kbinput1          ; ensure mask didn't leave 0
               tax                     ;
               jmp   kbdone            ;
kbcnvt4        lda   ASCIITBL,x        ; get ascii code
               beq   kbinput1          ; if ascii code is 0, invalid scancode, get another
               tax                     ; save ascii code in x reg
               lda   special           ;
               .byte #$89 ; bit #
							 .byte #$04              ; test caps lock
               beq   kbdone            ; caps lock off
               txa                     ; caps lock on - get ascii code
               cmp   #$61              ; test for lower case a
               bcc   kbdone            ; if less than, skip down
               cmp   #$7B              ; test for lower case z
               bcs   kbdone            ; if greater than, skip down
               sec                     ; alpha chr found, make it uppercase
               sbc   #$20              ; if caps on and lowercase, change to upper
               tax                     ; put new ascii to x reg
kbdone         .byte #$DA ; phx                     ; save ascii to stack
kbdone1        jsr   kbtscrl           ; turn on scroll lock (not ready to receive)
               beq   kbdone1           ; ensure scroll lock is on
               pla                     ; get ASCII code
               rts                     ; return to calling program
;
;******************************************************************************
;
; scan code processing routines
;
;
kbtrap83       lda   #$02              ; traps the F7 code of $83 and chang
               rts                     ;
;
kbsshift       lda   #$10              ; *** neat trick to tuck code inside harmless cmd
               .byte $2c               ; *** use BIT Absolute to skip lda #$02 below
kbsctrl        lda   #$08              ; *** disassembles as  LDA #$01
               ora   special           ;                      BIT $A902
               sta   special           ;                      ORA $02D3
               jmp   kbnull            ; return with 0 in A
;
kbtnum         lda   special           ; toggle numlock bit in special
               eor   #$02              ;
               sta   special           ;
               jsr   kbsled            ; update keyboard leds
               jmp   kbnull            ; return with 0 in A
;
kbresend       lda   lastbyte          ;
               jsr   kbsend            ;
               jmp   kbnull            ; return with 0 in A
;
kbtcaps        lda   special           ; toggle caps bit in special
               eor   #$04              ;
               sta   special           ;
               jsr   kbsled            ; set new status leds
kbnull         lda   #$00              ; set caps, get next code
               rts                     ;
;
kbExt          jsr   KBGET             ; get next code
               cmp   #$F0              ; is it an extended key release?
               beq   kbexrls           ; test for shift, ctrl, caps
               cmp   #$14              ; right control?
               beq   kbsctrl           ; set control and get next scancode
               ldx   #$03              ; test for 4 scancode to be relocated
kbext1         cmp   kbextlst,x        ; scan list
               beq   kbext3            ; get data if match found
               dex                     ; get next item
               bpl   kbext1            ;
               cmp   #$3F              ; not in list, test range 00-3f or 40-7f
               bmi   kbExt2            ; its a windows/alt key, just return unshifted
               ora   #$80              ; return scancode and point to shifted table
kbExt2         rts                     ;
kbext3         lda   kbextdat,x        ; get new scancode
               rts                     ;
;
kbextlst       .byte $7E               ; E07E ctrl-break scancode
               .byte $4A               ; E04A kp/
               .byte $12               ; E012 scancode
               .byte $7C               ; E07C prt scrn
;
kbextdat       .byte $20               ; new ctrl-brk scancode
               .byte $6A               ; new kp/ scancode
               .byte $00               ; do nothing (return and get next scancode)
               .byte $0F               ; new prt scrn scancode
;
kbexrls        jsr   KBGET             ;
               cmp   #$12              ; is it a release of the E012 code?
               bne   kbrlse1           ; no - process normal release
               jmp   kbnull            ; return with 0 in A
;
kbrlse         jsr   KBGET             ; test for shift & ctrl
               cmp   #$12              ;
               beq   kbrshift          ; reset shift bit
               cmp   #$59              ;
               beq   kbrshift          ;
kbrlse1        cmp   #$14              ;
               beq   kbrctrl           ;
               cmp   #$11              ; alt key release
               bne   kbnull            ; return with 0 in A
kbralt         lda   #$13              ; new alt release scancode
               rts                     ;
kbrctrl        lda   #$F7              ; reset ctrl bit in special
               .byte $2c               ; use (BIT Absolute) to skip lda #$EF if passing down
kbrshift       lda   #$EF              ; reset shift bit in special
               and   special           ;
               sta   special           ;
               jmp   kbnull            ; return with 0 in A
;
kbtscrl        lda   special           ; toggle scroll lock bit in special
               eor   #$01              ;
               sta   special           ;
               jsr   kbsled            ; update keyboard leds
               lda   special           ;
               .byte #$89 ; bit #
							 .byte #$01              ; check scroll lock status bit
               rts                     ; return
;
kbBrk          ldx   #$07              ; ignore next 7 scancodes then
kbBrk1         jsr   KBGET             ; get scancode
               dex                     ;
               bne   kbBrk1            ;
               lda   #$10              ; new scan code
               rts                     ;
;
kbcsrch        ldx   #$0E              ; 14 codes to check
kbcsrch1       cmp   kbclst,x          ; search scancode table for special processing
               beq   kbcsrch2          ; if found run the routine
               dex                     ;
               bpl   kbcsrch1          ;
               rts                     ; no match, return from here for further processing
kbcsrch2       txa                     ; code found - get index
               asl                     ; mult by two
               tax                     ; save back to x
               lda   byte              ; load scancode back into A
               ;jmp   (kbccmd,x)        ; execute scancode routine, return 0 if done ; 7C
							 .byte #$7C ; jmp (a.x)
							 .word kbccmd
                                       ; nonzero scancode if ready for ascii conversion
;
;keyboard command/scancode test list
; db=define byte, stores one byte of data
;
kbclst         .byte $83               ; F7 - move to scancode 02
               .byte $58               ; caps
               .byte $12               ; Lshift
               .byte $59               ; Rshift
               .byte $14               ; ctrl
               .byte $77               ; num lock
               .byte $E1               ; Extended pause break
               .byte $E0               ; Extended key handler
               .byte $F0               ; Release 1 byte key code
               .byte $FA               ; Ack
               .byte $AA               ; POST passed
               .byte $EE               ; Echo
               .byte $FE               ; resend
               .byte $FF               ; overflow/error
               .byte $00               ; underflow/error
;
; command/scancode jump table
;
kbccmd         .word kbtrap83          ;
               .word kbtcaps           ;
               .word kbsshift          ;
               .word kbsshift          ;
               .word kbsctrl           ;
               .word kbtnum            ;
               .word kbBrk             ;
               .word kbExt             ;
               .word kbrlse            ;
               .word kbnull            ;
               .word kbnull            ;
               .word kbnull            ;
               .word kbresend          ;
               .word kbflush           ;
               .word kbflush           ;
;
;**************************************************************
;
; Keyboard I/O suport
;

;
; KBSCAN will scan the keyboard for incoming data for about
; 105uS and returns with A=0 if no data was received.
; It does not decode anything, the non-zero value in A if data
; is ready is ambiguous.  You must call KBGET or KBINPUT to
; get the keyboard data.
;
KBSCAN         ldx   #$05              ; timer: x = (cycles - 40)/13   (105-40)/13=5
               lda   kbportddr         ;
               and   #$CF              ; set clk to input (change if port bits change)
               sta   kbportddr         ;
kbscan1        lda   #clk              ;
               bit   kbportreg         ;
               beq   kbscan2           ; if clk goes low, data ready
               dex                     ; reduce timer
               bne   kbscan1           ; wait while clk is high
               jsr   kbdis             ; timed out, no data, disable receiver
               lda   #$00              ; set data not ready flag
               rts                     ; return
kbscan2        jsr   kbdis             ; disable the receiver so other routines get it
; Three alternative exits if data is ready to be received: Either return or jmp to handler
               rts                     ; return (A<>0, A=clk bit mask value from kbdis)
;               jmp   KBINPUT           ; if key pressed, decode it with KBINPUT
;               jmp   KBGET             ; if key pressed, decode it with KBGET
;
;
kbflush        lda   #$f4              ; flush buffer
;
; send a byte to the keyboard
;
kbsend         sta   byte              ; save byte to send
               .byte #$DA ; phx                     ; save registers
               .byte #$5A ; phy                     ;
               sta   lastbyte          ; keep just in case the send fails
               lda   kbportreg         ;
               and   #$EF              ; clk low, data high (change if port bits change)
               ora   #data             ;
               sta   kbportreg         ;
               lda   kbportddr         ;
               ora   #$30              ;  bit bits high (change if port bits change)
               sta   kbportddr         ; set outputs, clk=0, data=1
               lda   #$10              ; 1Mhz cpu clock delay (delay = cpuclk/62500)
kbsendw        .byte #$3A ; dec A
               bne   kbsendw           ; 64uS delay
               ldy   #$00              ; parity counter
               ldx   #$08              ; bit counter
               lda   kbportreg         ;
               and   #$CF              ; clk low, data low (change if port bits change)
               sta   kbportreg         ;
               lda   kbportddr         ;
               and   #$EF              ; set clk as input (change if port bits change)
               sta   kbportddr         ; set outputs
               jsr   kbhighlow         ;
kbsend1        ror   byte              ; get lsb first
               bcs   kbmark            ;
               lda   kbportreg         ;
               and   #$DF              ; turn off data bit (change if port bits change)
               sta   kbportreg         ;
               jmp   kbnext            ;
kbmark         lda   kbportreg         ;
               ora   #data             ;
               sta   kbportreg         ;
               iny                     ; inc parity counter
kbnext         jsr   kbhighlow         ;
               dex                     ;
               bne   kbsend1           ; send 8 data bits
               tya                     ; get parity count
               and   #$01              ; get odd or even
               bne   kbpclr            ; if odd, send 0
               lda   kbportreg         ;
               ora   #data             ; if even, send 1
               sta   kbportreg         ;
               jmp   kback             ;
kbpclr         lda   kbportreg         ;
               and   #$DF              ; send data=0 (change if port bits change)
               sta   kbportreg         ;
kback          jsr   kbhighlow         ;
               lda   kbportddr         ;
               and   #$CF              ; set clk & data to input (change if port bits change)
               sta   kbportddr         ;
               .byte #$7A ; ply                     ; restore saved registers
               .byte #$FA ; plx                     ;
               jsr   kbhighlow         ; wait for ack from keyboard
               bne   KBINIT            ; VERY RUDE error handler - re-init the keyboard
kbsend2        lda   kbportreg         ;
               and   #clk              ;
               beq   kbsend2           ; wait while clk low
               jmp   kbdis             ; diable kb sending
;
; KBGET waits for one scancode from the keyboard
;
kberror        lda   #$FE              ; resend cmd
               jsr   kbsend            ;
KBGET          .byte #$DA ; phx                     ;
               .byte #$5A ; phy                     ;
               lda   #$00              ;
               sta   byte              ; clear scankey holder
               sta   parity            ; clear parity holder
               ldy   #$00              ; clear parity counter
               ldx   #$08              ; bit counter
               lda   kbportddr         ;
               and   #$CF              ; set clk to input (change if port bits change)
               sta   kbportddr         ;
kbget1         lda   #clk              ;
               bit   kbportreg         ;
               bne   kbget1            ; wait while clk is high
               lda   kbportreg         ;
               and   #data             ; get start bit
               bne   kbget1            ; if 1, false start bit, do again
kbget2         jsr   kbhighlow         ; wait for clk to return high then go low again
               cmp   #$01              ; set c if data bit=1, clr if data bit=0
                                       ; (change if port bits change) ok unless data=01 or 80
                                       ; in that case, use ASL or LSR to set carry bit
               ror   byte              ; save bit to byte holder
               bpl   kbget3            ;
               iny                     ; add 1 to parity counter
kbget3         dex                     ; dec bit counter
               bne   kbget2            ; get next bit if bit count > 0
               jsr   kbhighlow         ; wait for parity bit
               beq   kbget4            ; if parity bit 0 do nothing
               inc   parity            ; if 1, set parity to 1
kbget4         tya                     ; get parity count
               .byte #$7A ; ply                     ;
               .byte #$FA ; plx                     ;
               eor   parity            ; compare with parity bit
               and   #$01              ; mask bit 1 only
               beq   kberror           ; bad parity
               jsr   kbhighlow         ; wait for stop bit
               beq   kberror           ; 0=bad stop bit
               lda   byte              ; if byte & parity 0,
               beq   KBGET             ; no data, do again
               jsr   kbdis             ;
               lda   byte              ;
               rts                     ;
;
kbdis          lda   kbportreg         ; disable kb from sending more data
               and   #$EF              ; clk = 0 (change if port bits change)
               sta   kbportreg         ;
               lda   kbportddr         ; set clk to ouput low
               and   #$CF              ; (stop more data until ready) (change if port bits change)
               ora   #clk              ;
               sta   kbportddr         ;
               rts                     ;
;
KBINIT         lda   #$02              ; init - num lock on, all other off
               sta   special           ;
kbinit1        lda   #$ff              ; keybrd reset
               jsr   kbsend            ; reset keyboard
               jsr   KBGET             ;
               cmp   #$FA              ; ack?
               bne   kbinit1           ; resend reset cmd
               jsr   KBGET             ;
               cmp   #$AA              ; reset ok
               bne   kbinit1           ; resend reset cmd
                                       ; fall into to set the leds
kbsled         lda   #$ED              ; Set the keybrd LED's from kbleds variable
               jsr   kbsend            ;
               jsr   KBGET             ;
               cmp   #$FA              ; ack?
               bne   kbsled            ; resend led cmd
               lda   special           ;
               and   #$07              ; ensure bits 3-7 are 0
               jsr   kbsend            ;
               rts                     ;
                                       ;
kbhighlow      lda   #clk              ; wait for a low to high to low transition
               bit   kbportreg         ;
               beq   kbhighlow         ; wait while clk low
kbhl1          bit   kbportreg         ;
               bne   kbhl1             ; wait while clk is high
               lda   kbportreg         ;
               and   #data             ; get data line state
               rts                     ;
;*************************************************************
;
; Unshifted table for scancodes to ascii conversion
;                                      Scan|Keyboard
;                                      Code|Key
;                                      ----|----------
ASCIITBL       .byte $00               ; 00 no key pressed
               .byte $89               ; 01 F9
               .byte $87               ; 02 relocated F7
               .byte $85               ; 03 F5
               .byte $83               ; 04 F3
               .byte $81               ; 05 F1
               .byte $82               ; 06 F2
               .byte $8C               ; 07 F12
               .byte $00               ; 08
               .byte $8A               ; 09 F10
               .byte $88               ; 0A F8
               .byte $86               ; 0B F6
               .byte $84               ; 0C F4
               .byte $09               ; 0D tab
               .byte $60               ; 0E `~
               .byte $8F               ; 0F relocated Print Screen key
               .byte $03               ; 10 relocated Pause/Break key
               .byte $A0               ; 11 left alt (right alt too)
               .byte $00               ; 12 left shift
               .byte $E0               ; 13 relocated Alt release code
               .byte $00               ; 14 left ctrl (right ctrl too)
               .byte $71               ; 15 qQ
               .byte $31               ; 16 1!
               .byte $00               ; 17
               .byte $00               ; 18
               .byte $00               ; 19
               .byte $7A               ; 1A zZ
               .byte $73               ; 1B sS
               .byte $61               ; 1C aA
               .byte $77               ; 1D wW
               .byte $32               ; 1E 2@
               .byte $A1               ; 1F Windows 98 menu key (left side)
               .byte $02               ; 20 relocated ctrl-break key
               .byte $63               ; 21 cC
               .byte $78               ; 22 xX
               .byte $64               ; 23 dD
               .byte $65               ; 24 eE
               .byte $34               ; 25 4$
               .byte $33               ; 26 3#
               .byte $A2               ; 27 Windows 98 menu key (right side)
               .byte $00               ; 28
               .byte $20               ; 29 space
               .byte $76               ; 2A vV
               .byte $66               ; 2B fF
               .byte $74               ; 2C tT
               .byte $72               ; 2D rR
               .byte $35               ; 2E 5%
               .byte $A3               ; 2F Windows 98 option key (right click, right side)
               .byte $00               ; 30
               .byte $6E               ; 31 nN
               .byte $62               ; 32 bB
               .byte $68               ; 33 hH
               .byte $67               ; 34 gG
               .byte $79               ; 35 yY
               .byte $36               ; 36 6^
               .byte $00               ; 37
               .byte $00               ; 38
               .byte $00               ; 39
               .byte $6D               ; 3A mM
               .byte $6A               ; 3B jJ
               .byte $75               ; 3C uU
               .byte $37               ; 3D 7&
               .byte $38               ; 3E 8*
               .byte $00               ; 3F
               .byte $00               ; 40
               .byte $2C               ; 41 ,<
               .byte $6B               ; 42 kK
               .byte $69               ; 43 iI
               .byte $6F               ; 44 oO
               .byte $30               ; 45 0)
               .byte $39               ; 46 9(
               .byte $00               ; 47
               .byte $00               ; 48
               .byte $2E               ; 49 .>
               .byte $2F               ; 4A /?
               .byte $6C               ; 4B lL
               .byte $3B               ; 4C ;:
               .byte $70               ; 4D pP
               .byte $2D               ; 4E -_
               .byte $00               ; 4F
               .byte $00               ; 50
               .byte $00               ; 51
               .byte $27               ; 52 '"
               .byte $00               ; 53
               .byte $5B               ; 54 [{
               .byte $3D               ; 55 =+
               .byte $00               ; 56
               .byte $00               ; 57
               .byte $00               ; 58 caps
               .byte $00               ; 59 r shift
               .byte $0D               ; 5A <Enter>
               .byte $5D               ; 5B ]}
               .byte $00               ; 5C
               .byte $5C               ; 5D \|
               .byte $00               ; 5E
               .byte $00               ; 5F
               .byte $00               ; 60
               .byte $00               ; 61
               .byte $00               ; 62
               .byte $00               ; 63
               .byte $00               ; 64
               .byte $00               ; 65
               .byte $08               ; 66 bkspace
               .byte $00               ; 67
               .byte $00               ; 68
               .byte $31               ; 69 kp 1
               .byte $2f               ; 6A kp / converted from E04A in code
               .byte $34               ; 6B kp 4
               .byte $37               ; 6C kp 7
               .byte $00               ; 6D
               .byte $00               ; 6E
               .byte $00               ; 6F
               .byte $30               ; 70 kp 0
               .byte $2E               ; 71 kp .
               .byte $32               ; 72 kp 2
               .byte $35               ; 73 kp 5
               .byte $36               ; 74 kp 6
               .byte $38               ; 75 kp 8
               .byte $1B               ; 76 esc
               .byte $00               ; 77 num lock
               .byte $8B               ; 78 F11
               .byte $2B               ; 79 kp +
               .byte $33               ; 7A kp 3
               .byte $2D               ; 7B kp -
               .byte $2A               ; 7C kp *
               .byte $39               ; 7D kp 9
               .byte $8D               ; 7E scroll lock
               .byte $00               ; 7F
;
; Table for shifted scancodes
;
               .byte $00               ; 80
               .byte $C9               ; 81 F9
               .byte $C7               ; 82 relocated F7
               .byte $C5               ; 83 F5 (F7 actual scancode=83)
               .byte $C3               ; 84 F3
               .byte $C1               ; 85 F1
               .byte $C2               ; 86 F2
               .byte $CC               ; 87 F12
               .byte $00               ; 88
               .byte $CA               ; 89 F10
               .byte $C8               ; 8A F8
               .byte $C6               ; 8B F6
               .byte $C4               ; 8C F4
               .byte $09               ; 8D tab
               .byte $7E               ; 8E `~
               .byte $CF               ; 8F relocated Print Screen key
               .byte $03               ; 90 relocated Pause/Break key
               .byte $A0               ; 91 left alt (right alt)
               .byte $00               ; 92 left shift
               .byte $E0               ; 93 relocated Alt release code
               .byte $00               ; 94 left ctrl (and right ctrl)
               .byte $51               ; 95 qQ
               .byte $21               ; 96 1!
               .byte $00               ; 97
               .byte $00               ; 98
               .byte $00               ; 99
               .byte $5A               ; 9A zZ
               .byte $53               ; 9B sS
               .byte $41               ; 9C aA
               .byte $57               ; 9D wW
               .byte $40               ; 9E 2@
               .byte $E1               ; 9F Windows 98 menu key (left side)
               .byte $02               ; A0 relocated ctrl-break key
               .byte $43               ; A1 cC
               .byte $58               ; A2 xX
               .byte $44               ; A3 dD
               .byte $45               ; A4 eE
               .byte $24               ; A5 4$
               .byte $23               ; A6 3#
               .byte $E2               ; A7 Windows 98 menu key (right side)
               .byte $00               ; A8
               .byte $20               ; A9 space
               .byte $56               ; AA vV
               .byte $46               ; AB fF
               .byte $54               ; AC tT
               .byte $52               ; AD rR
               .byte $25               ; AE 5%
               .byte $E3               ; AF Windows 98 option key (right click, right side)
               .byte $00               ; B0
               .byte $4E               ; B1 nN
               .byte $42               ; B2 bB
               .byte $48               ; B3 hH
               .byte $47               ; B4 gG
               .byte $59               ; B5 yY
               .byte $5E               ; B6 6^
               .byte $00               ; B7
               .byte $00               ; B8
               .byte $00               ; B9
               .byte $4D               ; BA mM
               .byte $4A               ; BB jJ
               .byte $55               ; BC uU
               .byte $26               ; BD 7&
               .byte $2A               ; BE 8*
               .byte $00               ; BF
               .byte $00               ; C0
               .byte $3C               ; C1 ,<
               .byte $4B               ; C2 kK
               .byte $49               ; C3 iI
               .byte $4F               ; C4 oO
               .byte $29               ; C5 0)
               .byte $28               ; C6 9(
               .byte $00               ; C7
               .byte $00               ; C8
               .byte $3E               ; C9 .>
               .byte $3F               ; CA /?
               .byte $4C               ; CB lL
               .byte $3A               ; CC ;:
               .byte $50               ; CD pP
               .byte $5F               ; CE -_
               .byte $00               ; CF
               .byte $00               ; D0
               .byte $00               ; D1
               .byte $22               ; D2 '"
               .byte $00               ; D3
               .byte $7B               ; D4 [{
               .byte $2B               ; D5 =+
               .byte $00               ; D6
               .byte $00               ; D7
               .byte $00               ; D8 caps
               .byte $00               ; D9 r shift
               .byte $0D               ; DA <Enter>
               .byte $7D               ; DB ]}
               .byte $00               ; DC
               .byte $7C               ; DD \|
               .byte $00               ; DE
               .byte $00               ; DF
               .byte $00               ; E0
               .byte $00               ; E1
               .byte $00               ; E2
               .byte $00               ; E3
               .byte $00               ; E4
               .byte $00               ; E5
               .byte $08               ; E6 bkspace
               .byte $00               ; E7
               .byte $00               ; E8
               .byte $91               ; E9 kp 1
               .byte $2f               ; EA kp / converted from E04A in code
               .byte $94               ; EB kp 4
               .byte $97               ; EC kp 7
               .byte $00               ; ED
               .byte $00               ; EE
               .byte $00               ; EF
               .byte $90               ; F0 kp 0
               .byte $7F               ; F1 kp .
               .byte $92               ; F2 kp 2
               .byte $95               ; F3 kp 5
               .byte $96               ; F4 kp 6
               .byte $98               ; F5 kp 8
               .byte $1B               ; F6 esc
               .byte $00               ; F7 num lock
               .byte $CB               ; F8 F11
               .byte $2B               ; F9 kp +
               .byte $93               ; FA kp 3
               .byte $2D               ; FB kp -
               .byte $2A               ; FC kp *
               .byte $99               ; FD kp 9
               .byte $CD               ; FE scroll lock
; NOT USED     .byte $00               ; FF
; end

; https://raw.githubusercontent.com/jefftranter/6502/master/asm/tinybasic/TinyBasic.asm
;
; Tiny Basic starts here
;
;         .org     $7600             ; Start of Basic.
START

         JMP      FBLK              ; Jump to initialization code. So load address is start address.

CV       JMP      COLD_S            ; Cold start vector
WV       JMP      WARM_S            ; Warm start vector
IN_V     JMP      RCCHR             ; Input routine address.
OUT_V    JMP      SNDCHR            ; Output routine address.
BV       JMP      BREAK             ; Begin break routine

;
; Some codes
;
BSC      .byte $08                   ; Backspace code
LSC      .byte $1B                   ; Line cancel code (ESC)
PCC      .byte $00                   ; Pad character control
TMC      .byte $00                   ; Tape mode control
SSS      .byte $20                   ; Spare Stack size. (was $04 but documentation suggests $20)

;
; Code fragment for 'PEEK' and 'POKE'
;
PEEK     STX $C3                   ; 'PEEK' - store X in $C3
         BCC LBL008                ; On carry clear goto LBL008
         STX $C3                   ; 'POKE' - store X in $C3
         STA ($C2),Y               ; Store A in location pointed to by $C3 (hi) and Y (lo)
         RTS                       ; Return
LBL008   LDA ($C2),Y               ; Load A with value pointed to by $C3 (hi) and Y (lo)
         LDY #$00                  ; Reset Y
         RTS                       ; Return

;
; The following table contains the addresses for the ML handlers for the IL opcodes.
;
SRVT     .word  IL_BBR               ; ($40-$5F) Backward Branch Relative
         .word  IL_FBR               ; ($60-$7F) Forward Branch Relative
         .word  IL__BC               ; ($80-$9F) String Match Branch
         .word  IL__BV               ; ($A0-$BF) Branch if not Variable
         .word  IL__BN               ; ($C0-$DF) Branch if not a Number
         .word  IL__BE               ; ($E0-$FF) Branch if not End of line
         .word  IL__NO               ; ($08) No Opertion
         .word  IL__LB               ; ($09) Push Literal Byte onto Stack
         .word  IL__LN               ; ($0A) Push Literal Number
         .word  IL__DS               ; ($0B) Duplicate Top two bytes on Stack
         .word  IL__SP               ; ($0C) Stack Pop
         .word  IL__NO               ; ($0D) (Reserved)
         .word  IL__NO               ; ($0E) (Reserved)
         .word  IL__NO               ; ($0F) (Reserved)
         .word  IL__SB               ; ($10) Save Basic Pointer
         .word  IL__RB               ; ($11) Restore Basic Pointer
         .word  IL__FV               ; ($12) Fetch Variable
         .word  IL__SV               ; ($13) Store Variable
         .word  IL__GS               ; ($14) Save GOSUB line
         .word  IL__RS               ; ($15) Restore saved line
         .word  IL__GO               ; ($16) GOTO
         .word  IL__NE               ; ($17) Negate
         .word  IL__AD               ; ($18) Add
         .word  IL__SU               ; ($19) Subtract
         .word  IL__MP               ; ($1A) Multiply
         .word  IL__DV               ; ($1B) Divide
         .word  IL__CP               ; ($1C) Compare
         .word  IL__NX               ; ($1D) Next BASIC statement
         .word  IL__NO               ; ($1E) (Reserved)
         .word  IL__LS               ; ($1F) List the program
         .word  IL__PN               ; ($20) Print Number
         .word  IL__PQ               ; ($21) Print BASIC string
         .word  IL__PT               ; ($22) Print Tab
         .word  IL__NL               ; ($23) New Line
         .word  IL__PC               ; ($24) Print Literal String
         .word  IL__NO               ; ($25) (Reserved)
         .word  IL__NO               ; ($26) (Reserved)
         .word  IL__GL               ; ($27) Get input Line
         .word  ILRES1               ; ($28) (Seems to be reserved - No IL opcode calls this)
         .word  ILRES2               ; ($29) (Seems to be reserved - No IL opcode calls this)
         .word  IL__IL               ; ($2A) Insert BASIC Line
         .word  IL__MT               ; ($2B) Mark the BASIC program space Empty
         .word  IL__XQ               ; ($2C) Execute
         .word  WARM_S               ; ($2D) Stop (Warm Start)
         .word  IL__US               ; ($2E) Machine Language Subroutine Call
         .word  IL__RT               ; ($2F) IL subroutine return

ERRSTR   .byte " AT "                ; " AT " string used in error reporting.  Tom was right about this.
         .byte $80                   ; String terminator

LBL002   .word  ILTBL                ; Address of IL program table

;
; Begin Cold Start
;
; Load start of free ram ($0200) into locations $20 and $21
; and initialize the address for end of free ram ($22 & $23)
;
COLD_S   lda #$00                   ; Load accumulator with $00
         sta $20                    ; Store $00 in $20
         sta $22                    ; Store $00 in $22
         lda #$02                   ; Load accumulator with $02
         sta $21                    ; Store $02 in $21
         sta $23                    ; Store $02 in $23
;
;
; Begin test for free ram
;

         ldy #$01                   ; Load register Y with $01
MEM_T    lda ($22),Y                ; Load accumulator With the contents of a byte of memory
         tax                        ; Save it to X
         eor #$FF                   ; Next 4 instuctions test to see if this memory location
         sta ($22),Y                ; is ram by trying to write something new to it - new value
         cmp ($22),Y                ; gets created by XORing the old value with $FF - store the
         php                        ; result of the test on the stack to look at later
         txa                        ; Retrieve the old memory value
         sta ($22),Y                ; Put it back where it came from
         inc $22                    ; Increment $22 (for next memory location)
         bne SKP_PI                 ; Skip if we don't need to increment page
         inc $23                    ; Increment $23 (for next memory page)
SKP_PI   lda $23                    ; Get high byte of memory address
         cmp #>START                ; Did we reach start address of Tiny Basic?
         bne PULL                   ; Branch if not
         lda $22                    ; Get low byte of memory address
         cmp #<START                ; Did we reach start address of Tiny Basic?
         beq TOP                    ; If so, stop memory test so we don't overwrite ourselves
PULL
         plp                        ; Now look at the result of the memory test
         beq MEM_T                  ; Go test the next memory location if the last one was ram
TOP
         dey                        ; If last memory location did not test as ram, decrement Y (should be $00 now)

IL__MT   cld                        ; Make sure we're not in decimal mode
         lda $20                    ; Load up the low-order by of the start of free ram
         adc SSS                    ; Add to the spare stack size
         sta $24                    ; Store the result in $0024
         tya                        ; Retrieve Y
         adc $21                    ; And add it to the high order byte of the start of free ram (this does not look right)
         sta $25                    ; Store the result in $0025
         tya                        ; Retrieve Y again
         sta ($20),Y                ; Store A in the first byte of program memory
         iny                        ; Increment Y
         sta ($20),Y                ; Store A in the second byte of program memory
;
;Begin Warm Start
;
WARM_S   lda $22
         sta $C6
         sta $26
         lda $23
         sta $C7
         sta $27
         jsr P_NWLN                 ; Go print CR, LF and pad characters
LBL014   lda LBL002                 ; Load up the start of the IL Table
         sta $2A                    ;
         lda LBL002+$01             ;
         sta $2B
         lda #$80
         sta $C1
         lda #$30
         sta $C0
         ldx #$00
         stx $BE
         stx $C2
         dex
         txs

;
; IL execution loop
;
LBL006   cld                        ; Make sure we're in binary mode
         jsr LBL004                 ; Go read a byte from the IL program table
         jsr LBL005                 ; Go decide what to do with it
         jmp LBL006                 ; Repeat
;
;
;
         .byte $83                   ; No idea about this
         .byte $65                   ; No idea about this
;
;
; Routine to service the TBIL Instructions
;
LBL005   cmp #$30                   ;
         bcs LBL011                 ; If it's $30 or higher, it's a Branch or Jump - go handle it
         cmp #$08                   ;
         bcc LBL007                 ; If it's less than $08 it's a stack exchange - go handle it
         asl                        ; Multiply the OP code by 2
         tax                        ; Transfer it to X
LBL022   lda SRVT-$03,X             ; Get the hi byte of the OP Code handling routine
         pha                        ; and save it on the stack
         lda SRVT-$04,X             ; Get the lo byte
         pha                        ; and save it on the stack
         php                        ; save the processor status too
         rti                        ; now go execute the OP Code handling routine
;
;
; Routine to handle the stack exchange
;
LBL007   adc $C1
         tax
         lda ($C1),Y
         pha
         lda $00,X
         sta ($C1),Y
         pla
         sta $00,X
         rts
;
;
;
LBL015   jsr P_NWLN                 ; Go print CR, LF and pad characters
         lda #$21                   ; '!' character
         jsr OUT_V                  ; Go print it
         lda $2A                    ; Load the current TBIL pointer (lo)
         sec                        ; Set the carry flag
         sbc LBL002                 ; Subtract the TBIL table origin (lo)
         tax                        ; Move the difference to X
         lda $2B                    ; Load the current TBIL pointer (hi)
         sbc LBL002+$01             ; Subtract the TBIL table origin (hi)
         jsr LBL010
         lda $BE
         beq LBL012
         lda #<ERRSTR               ; Get lo byte of error string address
         sta $2A                    ; Put in $2A
         lda #>ERRSTR               ; Get hi byte of error string address
         sta $2B                    ; Put in $2B
         jsr IL__PC                 ; Go report an error has been detected
         ldx $28
         lda $29
         jsr LBL010
LBL012   lda #$07                   ; ASCII Bell
         jsr OUT_V                  ; Go ring Bell
         jsr P_NWLN                 ; Go print CR, LF and pad characters
LBL060   lda $26
         sta $C6
         lda $27
         sta $C7
         jmp LBL014
;
;
;
LBL115   ldx #$7C
LBL048   cpx $C1
LBL019   bcc LBL015
         ldx $C1
         inc $C1
         inc $C1
         clc
         rts
;
;
;
IL_BBR   dec $BD                    ; Entry point for TBIL Backward Branch Relative
IL_FBR   lda $BD                    ; Entry point for TBIL Forward Branch Relative
         beq LBL015
LBL017   lda $BC
         sta $2A
         lda $BD
         sta $2B
         rts
;
; Jump handling routine
;
LBL011   cmp #$40
         bcs LBL016                 ; If it's not a Jump, go to branch handler
         pha
         jsr LBL004                 ; Go read a byte from the TBIL table
         adc LBL002
         sta $BC
         pla
         pha
         and #$07
         adc LBL002+$01
         sta $BD
         pla
         and #$08
         bne LBL017
         lda $BC
         ldx $2A
         sta $2A
         stx $BC
         lda $BD
         ldx $2B
         sta $2B
         stx $BD
LBL126   lda $C6
         sbc #$01
         sta $C6
         bcs LBL018
         dec $C7
LBL018   cmp $24
         lda $C7
         sbc $25
         bcc LBL019
         lda $BC
         sta ($C6),Y
         iny
         lda $BD
         sta ($C6),Y
         rts
;
;
; Branch Handler
;
LBL016   pha
         lsr
         lsr
         lsr
         lsr
         and #$0E
         tax
         pla
         cmp #$60
         and #$1F
         bcs LBL020
         ora #$E0
LBL020   clc
         beq LBL021
         adc $2A
         sta $BC
         tya
         adc $2B
LBL021   sta $BD
         jmp LBL022
;
;
;
IL__BC   lda $2C                    ; Entry point for TBIL BC (String Match Branch)
         sta $B8
         lda $2D
         sta $B9
LBL025   jsr LBL023
         jsr LBL024
         eor ($2A),Y
         tax
         jsr LBL004                 ; Go read a byte from the TBIL table
         txa
         beq LBL025
         asl
         beq LBL026
         lda $B8
         sta $2C
         lda $B9
         sta $2D
LBL028   jmp IL_FBR
IL__BE   jsr LBL023                 ; Entry point for TBIL BE (Branch if not End of line)
         cmp #$0D
         bne LBL028
LBL026   rts
;
;
;
IL__BV   jsr LBL023                 ; Entry point for TBIL BV (Branch if not Variable)
         cmp #$5B
         bcs LBL028
         cmp #$41
         bcc LBL028
         asl
         jsr LBL029
LBL024   ldy #$00
         lda ($2C),Y
         inc $2C
         bne LBL030
         inc $2D
LBL030   cmp #$0D
         clc
         rts
;
;
;
LBL031   jsr LBL024
LBL023   lda ($2C),Y
         cmp #$20
         beq LBL031
         cmp #$3A
         clc
         bpl LBL032
         cmp #$30
LBL032   rts
;
;
;
IL__BN   jsr LBL023                 ; Entry point for TBIL BN (Branch if not a Number)
         bcc LBL028
         sty $BC
         sty $BD
LBL033   lda $BC
         ldx $BD
         asl $BC
         rol $BD
         asl $BC
         rol $BD
         clc
         adc $BC
         sta $BC
         txa
         adc $BD
         asl $BC
         rol
         sta $BD
         jsr LBL024
         and #$0F
         adc $BC
         sta $BC
         tya
         adc $BD
         sta $BD
         jsr LBL023
         bcs LBL033
         jmp LBL034
LBL061   jsr IL__SP
         lda $BC
         ora $BD
         beq LBL036
LBL065   lda $20
         sta $2C
         lda $21
         sta $2D
LBL040   jsr LBL037
         beq LBL038
         lda $28
         cmp $BC
         lda $29
         sbc $BD
         bcs LBL038
LBL039   jsr LBL024
         bne LBL039
         jmp LBL040
LBL038   lda $28
         eor $BC
         bne LBL041
         lda $29
         eor $BD
LBL041   rts
;
;
;
LBL043   jsr LBL042
IL__PC   jsr LBL004                 ; Entry point for TBIL PC (print literal) - Go read a byte from the TBIL table
         bpl LBL043
LBL042   inc $BF
         bmi LBL044
         jmp OUT_V                  ; Go print it
LBL044   dec $BF
LBL045   rts
;
;
;
LBL046   cmp #$22
         beq LBL045
         jsr LBL042
IL__PQ   jsr LBL024                 ; Entry point for TBIL PQ
         bne LBL046
LBL036   jmp LBL015
IL__PT   lda #$20                   ; Entry point for TBIL PT
         jsr LBL042
         lda $BF
         and #$87
         bmi LBL045
         bne IL__PT
         rts
;
;
;
IL__CP   ldx #$7B
         jsr LBL048
         inc $C1
         inc $C1
         inc $C1
         sec
         lda $03,X
         sbc $00,X
         sta $00,X
         lda $04,X
         sbc $01,X
         bvc LBL052
         eor #$80
         ora #$01
LBL052   bmi LBL053
         bne LBL054
         ora $00,X
         beq LBL049
LBL054   lsr $02,X
LBL049   lsr $02,X
LBL053   lsr $02,X
         bcc LBL050
LBL004   ldy #$00                   ; Read a byte from the TBIL Table
         lda ($2A),Y               ;
         inc $2A                    ; Increment TBIL Table pointer as required
         bne LBL051                 ;
         inc $2B                    ;
LBL051   ora #$00                   ; Check for $00 and set the 'Z' flag acordingly
LBL050   rts                        ; Return
;
;
;
IL__NX   lda $BE                    ; Entry point for TBIL NX
         beq LBL055
LBL056   jsr LBL024
         bne LBL056
         jsr LBL037
         beq LBL057
LBL062   jsr LBL058
         jsr BV                     ; Test for break
         bcs LBL059
         lda $C4
         sta $2A
         lda $C5
         sta $2B
         rts
;
;
;
LBL059   lda LBL002
         sta $2A
         lda LBL002+$01
         sta $2B
LBL057   jmp LBL015
LBL055   sta $BF
         jmp LBL060
IL__XQ   lda $20                    ; Entry point fro TBIL XQ
         sta $2C
         lda $21
         sta $2D
         jsr LBL037
         beq LBL057
         lda $2A
         sta $C4
         lda $2B
         sta $C5
LBL058   lda #$01
         sta $BE
         rts
;
;
;
IL__GO   jsr LBL061                 ; Entry point for TBIL GO
         beq LBL062
LBL066   lda $BC
         sta $28
         lda $BD
         sta $29
         jmp LBL015
IL__RS   jsr LBL063                 ; Entry point for TBIL RS
         jsr LBL064
         jsr LBL065
         bne LBL066
         rts
;
;
;
LBL037   jsr LBL024
         sta $28
         jsr LBL024
         sta $29
         ora $28
         rts
;
;
;
IL__DS   jsr IL__SP                 ; Entry point for TBIL DS
         jsr LBL034
LBL034   lda $BD
LBL131   jsr LBL029
         lda $BC
LBL029   ldx $C1
         dex
         sta $00,X
         stx $C1
         cpx $C0
         bne IL__NO
LBL068   jmp LBL015
LBL097   ldx $C1
         cpx #$80
         bpl LBL068
         lda $00,X
         inc $C1
IL__NO   rts                        ; Entry point for the TBIL NO
;
;
;
LBL010   sta $BD
         stx $BC
         jmp LBL069
IL__PN   ldx $C1                    ; Entry point for the TBIL PN
         lda $01,X
         bpl LBL070
         jsr IL__NE
         lda #$2D
         jsr LBL042
LBL070   jsr IL__SP
LBL069   lda #$1F
         sta $B8
         sta $BA
         lda #$2A
         sta $B9
         sta $BB
         ldx $BC
         ldy $BD
         sec
LBL072   inc $B8
         txa
         sbc #$10
         tax
         tya
         sbc #$27
         tay
         bcs LBL072
LBL073   dec $B9
         txa
         adc #$E8
         tax
         tya
         adc #$03
         tay
         bcc LBL073
         txa
LBL074   sec
         inc $BA
         sbc #$64
         bcs LBL074
         dey
         bpl LBL074
LBL075   dec $BB
         adc #$0A
         bcc LBL075
         ora #$30
         sta $BC
         lda #$20
         sta $BD
         ldx #$FB
LBL199   stx $C3
         lda $BD,X
         ora $BD
         cmp #$20
         beq LBL076
         ldy #$30
         sty $BD
         ora $BD
         jsr LBL042
LBL076   ldx $C3
         inx
         bne LBL199
         rts
;
;
;
IL__LS   lda $2D                    ; Entry point for TBIL LS
         pha
         lda $2C
         pha
         lda $20
         sta $2C
         lda $21
         sta $2D
         lda $24
         ldx $25
         jsr LBL077
         beq LBL078
         jsr LBL077
LBL078   lda $2C
         sec
         sbc $B6
         lda $2D
         sbc $B7
         bcs LBL079
         jsr LBL037
         beq LBL079
         ldx $28
         lda $29
         jsr LBL010
         lda #$20
LBL080   jsr LBL042
         jsr BV                     ; Test for break
         bcs LBL079
         jsr LBL024
         bne LBL080
         jsr IL__NL
         jmp LBL078
LBL077   sta $B6
         inc $B6
         bne LBL082
         inx
LBL082   stx $B7
         ldy $C1
         cpy #$80
         beq LBL083
         jsr LBL061
LBL099   lda $2C
         ldx $2D
         sec
         sbc #$02
         bcs LBL084
         dex
LBL084   sta $2C
         jmp LBL085
LBL079   pla
         sta $2C
         pla
         sta $2D
LBL083   rts
IL__NL   lda $BF                    ; Entry point for TBIL NL
         bmi LBL083
;
;
; Routine to print a new line.  It handles CR, LF
; and adds pad characters to the ouput
;
P_NWLN   lda #$0D                   ; Load up a CR
         jsr OUT_V                  ; Go print it
         lda PCC                    ; Load the pad character code
         and #$7F                   ; Test to see -
         sta $BF                    ; how many pad characters to print
         beq LBL086                 ; Skip if 0
LBL088   jsr LBL087                 ; Go print pad character
         dec $BF                    ; One less
         bne LBL088                 ; Loop until 0
LBL086   lda #$0A                   ; Load up a LF
         jmp LBL089                 ; Go print it

;
;
;
LBL092   ldy TMC
LBL091   sty $BF
         bcs LBL090
IL__GL   lda #$30                   ; Entry pont for TBIL GL
         sta $2C
         sta $C0
         sty $2D
         jsr LBL034
LBL090   eor $80
         sta $80
         jsr IN_V
         ldy #$00
         ldx $C0
         and #$7F
         beq LBL090
         cmp #$7F
         beq LBL090
         cmp #$13
         beq LBL091
         cmp #$0A
         beq LBL092
         cmp LSC
         beq LBL093
         cmp BSC
         bne LBL094
         cpx #$30
         bne LBL095
LBL093   ldx $2C
         sty $BF
         lda #$0D
LBL094   cpx $C1
         bmi LBL096
         lda #$07
         jsr LBL042
         jmp LBL090
LBL096   sta $00,X
         inx
         inx
LBL095   dex
         stx $C0
         cmp #$0D
         bne LBL090
         jsr IL__NL
IL__SP   jsr LBL097                 ; Entry point for TBIL SP
         sta $BC
         jsr LBL097
         sta $BD
         rts
;
;
;
IL__IL   jsr LBL098                 ; Entry point for TBIL IL
         jsr LBL061
         php
         jsr LBL099
         sta $B8
         stx $B9
         lda $BC
         sta $B6
         lda $BD
         sta $B7
         ldx #$00
         plp
         bne LBL100
         jsr LBL037
         dex
         dex
LBL101   dex
         jsr LBL024
         bne LBL101
LBL100   sty $28
         sty $29
         jsr LBL098
         lda #$0D
         cmp ($2C),Y
         beq LBL102
         inx
         inx
         inx
LBL103   inx
         iny
         cmp ($2C),Y
         bne LBL103
         lda $B6
         sta $28
         lda $B7
         sta $29
LBL102   lda $B8
         sta $BC
         lda $B9
         sta $BD
         clc
         ldy #$00
         txa
         beq LBL104
         bpl LBL105
         adc $2E
         sta $B8
         lda $2F
         sbc #$00
         sta $B9
LBL109   lda ($2E),Y
         sta ($B8),Y
         ldx $2E
         cpx $24
         bne LBL106
         lda $2F
         cmp $25
         beq LBL107
LBL106   inx
         stx $2E
         bne LBL108
         inc $2F
LBL108   inc $B8
         bne LBL109
         inc $B9
         bne LBL109
LBL105   adc $24
         sta $B8
         sta $2E
         tya
         adc $25
         sta $B9
         sta $2F
         lda $2E
         sbc $C6
         lda $2F
         sbc $C7
         bcc LBL110
         dec $2A
         jmp LBL015
LBL110   lda ($24),Y
         sta ($2E),Y
         ldx $24
         bne LBL111
         dec $25
LBL111   dec $24
         ldx $2E
         bne LBL112
         dec $2F
LBL112   dex
         stx $2E
         cpx $BC
         bne LBL110
         ldx $2F
         cpx $BD
         bne LBL110
LBL107   lda $B8
         sta $24
         lda $B9
         sta $25
LBL104   lda $28
         ora $29
         beq LBL113
         lda $28
         sta ($BC),Y
         iny
         lda $29
         sta ($BC),Y
LBL114   iny
         sty $B6
         jsr LBL024
         php
         ldy $B6
         sta ($BC),Y
         plp
         bne LBL114
LBL113   jmp LBL014
IL__DV   jsr LBL115
         lda $03,X
         and #$80
         beq LBL116
         lda #$FF
LBL116   sta $BC
         sta $BD
         pha
         adc $02,X
         sta $02,X
         pla
         pha
         adc $03,X
         sta $03,X
         pla
         eor $01,X
         sta $BB
         bpl LBL117
         jsr LBL118
LBL117   ldy #$11
         lda $00,X
         ora $01,X
         bne LBL119
         jmp LBL015
LBL119   sec
         lda $BC
         sbc $00,X
         pha
         lda $BD
         sbc $01,X
         pha
         eor $BD
         bmi LBL120
         pla
         sta $BD
         pla
         sta $BC
         sec
         jmp LBL121
LBL120   pla
         pla
         clc
LBL121   rol $02,X
         rol $03,X
         rol $BC
         rol $BD
         dey
         bne LBL119
         lda $BB
         bpl LBL122
IL__NE   ldx $C1                    ; Entry point for TBIL NE
LBL118   sec
         tya
         sbc $00,X
         sta $00,X
         tya
         sbc $01,X
         sta $01,X
LBL122   rts
;
;
;
IL__SU   jsr IL__NE                 ; Entry point for TBIL SU
IL__AD   jsr LBL115                 ; Entry point for TBIL AD
         lda $00,X
         adc $02,X
         sta $02,X
         lda $01,X
         adc $03,X
         sta $03,X
         rts
;
;
;
IL__MP   jsr LBL115                 ; Entry point for TBIL MP
         ldy #$10
         lda $02,X
         sta $BC
         lda $03,X
         sta $BD
LBL124   asl $02,X
         rol $03,X
         rol $BC
         rol $BD
         bcc LBL123
         clc
         lda $02,X
         adc $00,X
         sta $02,X
         lda $03,X
         adc $01,X
         sta $03,X
LBL123   dey
         bne LBL124
         rts
;
;
;
IL__FV   jsr LBL097                 ; Entry point for TBIL FV
         tax
         lda $00,X
         ldy $01,X
         dec $C1
         ldx $C1
         sty $00,X
         jmp LBL029
IL__SV   ldx #$7D                   ; Entry point for TBIL SV
         jsr LBL048
         lda $01,X
         pha
         lda $00,X
         pha
         jsr LBL097
         tax
         pla
         sta $00,X
         pla
         sta $01,X
         rts
IL__RT   jsr LBL063
         lda $BC
         sta $2A
         lda $BD
         sta $2B
         rts
;
;
;
IL__SB   ldx #$2C                   ; Entry point for TBIL SB
         bne LBL125
IL__RB   ldx #$2E                   ; Entry point for TBIL RB
LBL125   lda $00,X
         cmp #$80
         bcs LBL098
         lda $01,X
         bne LBL098
         lda $2C
         sta $2E
         lda $2D
         sta $2F
         rts
;
;
;
LBL098   lda $2C
         ldy $2E
         sty $2C
         sta $2E
         lda $2D
         ldy $2F
         sty $2D
         sta $2F
         ldy #$00
         rts
;
;
;
IL__GS   lda $28                    ; Entry point for TBIL GS
         sta $BC
         lda $29
         sta $BD
         jsr LBL126
         lda $C6
         sta $26
         lda $C7
LBL064   sta $27
LBL129   rts
;
;
;
LBL063   lda ($C6),Y
         sta $BC
         jsr LBL127
         lda ($C6),Y
         sta $BD
LBL127   inc $C6
         bne LBL128
         inc $C7
LBL128   lda $22
         cmp $C6
         lda $23
         sbc $C7
         bcs LBL129
         jmp LBL015
IL__US   jsr LBL130
         sta $BC
         tya
         jmp LBL131
LBL130   jsr IL__SP
         lda $BC
         sta $B6
         jsr IL__SP
         lda $BD
         sta $B7
         ldy $BC
         jsr IL__SP
         ldx $B7
         lda $B6
         clc
         jmp ($00BC)
IL__LN   jsr IL__LB                 ; Entry point for TBIL LN
IL__LB   jsr LBL004                 ; Entry point for TBIL LB - Go read a byte from the IL table
         jmp LBL029
LBL085   stx $2D
         cpx #$00
         rts
;
;
;
ILRES2   ldy #$02                   ; These two entry points are for code that
ILRES1   sty $BC                    ;  does not seem to get called.  Need more research.
         ldy #$29
         sty $BD
         ldy #$00
         lda ($BC),Y
         cmp #$08
         bne LBL133
         jmp LBL117
LBL133   rts
;
;
; Subroutine to decide which pad characters to print
;
LBL089   jsr OUT_V                  ; Entry point with a character to print first
LBL087   lda #$FF                   ; Normal entry point - Set pad to $FF
         bit PCC                    ; Check if the pad flag is on
         bmi LBL134                 ; Skip it if not
         lda #$00                   ; set pad to $00
LBL134   jmp OUT_V                  ; Go print it


;
; TBIL program table
;
ILTBL    .byte $24, $3E, $91, $27, $10, $E1, $59, $C5, $2A, $56, $10, $11, $2C, $8B, $4C
         .byte $45, $D4, $A0, $80, $BD, $30, $BC, $E0, $13, $1D, $94, $47, $CF, $88, $54
         .byte $CF, $30, $BC, $E0, $10, $11, $16, $80, $53, $55, $C2, $30, $BC, $E0, $14
         .byte $16, $90, $50, $D2, $83, $49, $4E, $D4, $E5, $71, $88, $BB, $E1, $1D, $8F
         .byte $A2, $21, $58, $6F, $83, $AC, $22, $55, $83, $BA, $24, $93, $E0, $23, $1D
         .byte $30, $BC, $20, $48, $91, $49, $C6, $30, $BC, $31, $34, $30, $BC, $84, $54
         .byte $48, $45, $CE, $1C, $1D, $38, $0D, $9A, $49, $4E, $50, $55, $D4, $A0, $10
         .byte $E7, $24, $3F, $20, $91, $27, $E1, $59, $81, $AC, $30, $BC, $13, $11, $82
         .byte $AC, $4D, $E0, $1D, $89, $52, $45, $54, $55, $52, $CE, $E0, $15, $1D, $85
         .byte $45, $4E, $C4, $E0, $2D, $98, $4C, $49, $53, $D4, $EC, $24, $00, $00, $00
         .byte $00, $0A, $80, $1F, $24, $93, $23, $1D, $30, $BC, $E1, $50, $80, $AC, $59
         .byte $85, $52, $55, $CE, $38, $0A, $86, $43, $4C, $45, $41, $D2, $2B, $84, $52
         .byte $45, $CD, $1D, $A0, $80, $BD, $38, $14, $85, $AD, $30, $D3, $17, $64, $81
         .byte $AB, $30, $D3, $85, $AB, $30, $D3, $18, $5A, $85, $AD, $30, $D3, $19, $54
         .byte $2F, $30, $E2, $85, $AA, $30, $E2, $1A, $5A, $85, $AF, $30, $E2, $1B, $54
         .byte $2F, $98, $52, $4E, $C4, $0A, $80, $80, $12, $0A, $09, $29, $1A, $0A, $1A
         .byte $85, $18, $13, $09, $80, $12, $01, $0B, $31, $30, $61, $72, $0B, $04, $02
         .byte $03, $05, $03, $1B, $1A, $19, $0B, $09, $06, $0A, $00, $00, $1C, $17, $2F
         .byte $8F, $55, $53, $D2, $80, $A8, $30, $BC, $31, $2A, $31, $2A, $80, $A9, $2E
         .byte $2F, $A2, $12, $2F, $C1, $2F, $80, $A8, $30, $BC, $80, $A9, $2F, $83, $AC
         .byte $38, $BC, $0B, $2F, $80, $A8, $52, $2F, $84, $BD, $09, $02, $2F, $8E, $BC
         .byte $84, $BD, $09, $93, $2F, $84, $BE, $09, $05, $2F, $09, $91, $2F, $80, $BE
         .byte $84, $BD, $09, $06, $2F, $84, $BC, $09, $95, $2F, $09, $04, $2F, $00, $00
         .byte $00
;
; End of Tiny Basic

MBLK
         .byte  "               vectron 65 basic"
				 .byte  $0D
         .byte  $FF
