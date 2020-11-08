;;;;
; Nick Bild
; nick.bild@gmail.com
; November 2020
;
; Reserved memory:
;
; $0000-$7EFF - RAM
; 		$0000-$0007 - Named variables
; 		$0100-$01FF - 6502 stack
;			$7923-$7EFF - Screen buffer.
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

    ; Init the keyboard, LEDs, and flags.
    jsr   KBINIT

		; Set initial screen address.
		lda #$01
		sta ScreenColumn
		lda #$01
		sta ScreenRow

    ; cli


MainLoop
		; Set cursor address.
		lda ScreenRow
		sta $7FF0
		lda ScreenColumn
		sta $7FF1

		lda #$7F		; Cursor.
		sta $7F00		; Latch cursor to display.

		jsr KBINPUT ; Wait for keyboard input, store ASCII code in A.

		;;;;
		; Handle special keys.
		;;;;

		; Is it <enter>?
		cmp #$0D
		bne NotEnter
		; Remove cursor.
		lda #$20
		sta $7F00
		; Move to start of next line.
		lda #$01
		sta ScreenColumn
		inc ScreenRow

		jmp NonPrintable
NotEnter

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
		jmp NonPrintable
NotBackSpace

		sta $7F00		; Latch character to display.

		; Increment cursor position.
		inc ScreenColumn

		;;;;
		; Handle line wrapping.
		;;;;

		lda #$31
		cmp ScreenColumn
		bne NoLineWrap
		lda #$01
		sta ScreenColumn
		inc ScreenRow
NoLineWrap

NonPrintable
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
