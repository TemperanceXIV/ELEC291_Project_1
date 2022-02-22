$NOLIST
$MODLP51
$LIST

CLK           EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE0  EQU ((2048*2)+100)
TIMER0_RATE1  EQU ((2048*2)-100)
TIMER0_RATE   EQU 4096     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))
; Timer rates are calculated away from the desired frequency. 8 times
TIMER0_RATEA EQU 1760*2		;A5 = 880 Hz
TIMER0_RATEE EQU 2350*2		;D5 = 587.33 Hz
TIMER0_RATEEf EQU 2600*2	; = 525 Hz
TIMER0_RATED EQU 2100*2
TIMER0_RATECS EQU 2000*2
TIMER0_RATEB EQU 1780*2

TIMER0_RELOAD0 EQU ((65536-(CLK/TIMER0_RATE0)))
TIMER0_RELOAD1 EQU ((65536-(CLK/TIMER0_RATE1)))
TIMER0_RELOADA EQU ((65536-(CLK/TIMER0_RATEA)))
TIMER0_RELOADE EQU ((65536-(CLK/TIMER0_RATEE)))
TIMER0_RELOADFS EQU ((65536-(CLK/TIMER0_RATEEf)))
TIMER0_RELOADD EQU ((65536-(CLK/TIMER0_RATED)))
TIMER0_RELOADCS EQU ((65536-(CLK/TIMER0_RATECS)))
TIMER0_RELOADB EQU ((65536-(CLK/TIMER0_RATEB)))

; notes are calibrated to be input directly into the Play_Note macro?
; Using an interval system with math.
key_A5 	equ 880		; A5 = 880 Hz, CLK/(440*8) = 62817.727272...
key_B5f equ 932		; B5f = 932.33333?

; Unison: 1:1
tone_P1a 	equ 1
tone_P1b	equ 1
; Minor Second is 16:15
tone_mi2a 	equ 16
tone_mi2b	equ	15
; Major Second: 9:8
tone_Ma2a	equ 9
tone_Ma2b	equ	8
; Minor Third: 6:5
tone_mi3a	equ 6
tone_mi3b	equ 5
; Major Third: 5:4
tone_Ma3a	equ 5
tone_Ma3b	equ 4
; Perfect Fourth: 4:3
tone_P4a	equ 4
tone_P4b	equ 3
; Tritone: 7:5
tone_tta	equ 7
tone_ttb	equ 5
; Perfect Fifth: 3:2
tone_P5a	equ 3
tone_P5b	equ 2
; Minor Sixth: 8:5
tone_mi6a	equ 8
tone_mi6b	equ 5
; Major Sixth: 5:3
tone_Ma6a	equ 5
tone_Ma6b	equ 3
; Minor Seventh: 9:5
tone_mi7a	equ 9
tone_mi7b	equ 5
; Major Seventh: 15:8
tone_Ma7a	equ 15
tone_Ma7b 	equ 8
; Octave: 2:1
tone_P8a	equ 2
tone_P8b	equ 1

SOUND_OUT EQU P1.1

org 0x0000
   ljmp Startup

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR
	
$NOLIST
$include(math32.inc)
$LIST

dseg at 30H
x:	ds 4
y:	ds 4
bcd:ds 5

bseg
mf: dbit 1

;Flag for whether to go up or down the interval.
;stepUpDown: dbit 1

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST
;						1234567890123456 
Initial_Message1: 	db 'Hello_World     ',0
Blank_Message:		db '                ',0
;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
InitTimer0:
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD)
	mov RL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P1.1 ;
;---------------------------------;
Timer0_ISR:
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns


   
;---------------------------------;
; Hardware and variable           ;
; initialization                  ;
;---------------------------------;

; BCD Display Macro
debug_BCD mac
lcall hex2bcd2
Set_Cursor(1,1)
Display_BCD(bcd+4)
Display_BCD(bcd+3)
Display_BCD(bcd+2)
Display_BCD(bcd+1)
Display_BCD(bcd+0)

endmac
    ; Note Macro 
    ; Play_Note([key], [first ratio], [second ratio], [note duration])
    ; Uses Resonant mechanics as opposed to equal-tempered mechanics
    ; First Parameter, determine what is the fundamental frequency
    ; Second Parameter, set the upper ratio for the note
    ; Third Parameter, set the lower ratio for the note
    ; Fourth Parameter, set the duration of the note
    ; 1 = 16th note
    ; 2 = 8th note
    ; 4 = quarter note
    ; 8 = half note
    ; 16 = whole note
    ; *You can compose notes of different values too*
    ; Plays a note for a certain duration
; select note base frequency as defined by fundamental frequency
; select duration of note (in 50 miliseconds increments as it is going off a pure delay
; The basic time increment is 0.05 seconds
Play_Note mac
	; Compute the reload value given the base frequency and interval ratio codes
; Calc_Interval([fundamental frequency], [Numerator], [Denominator])
;Calc_Interval:
; Freq0 loaded (fundamental frequency)
Load_x(%0) 
; Load upper ratio
Load_y(%1)
	lcall mul32
	
; Load lower ratio
Load_y(%2)
	lcall div32
; compute value for reload
; reload rate = CLK/freq
	Load_y(CLK)
	lcall xchg_xy
	
	lcall div32
	
; reload value = 65536-x
	Load_y(65536)
	lcall xchg_xy
	lcall sub32
; x now contains the reload value
;debug_BCD
	mov RL0, x+0
	mov RH0, x+1
	
	setb TR0
	; Note delay runs 50 ms according to the value held in register 2 (parameter 4)
	mov R2, %3
	lcall Play_Note_Delay
	clr TR0
	Wait_Milli_Seconds(#20)
endmac

; Based on TEMPO of music?
; Set based on the smallest time interval note.
; Moderato is about (108)-120 bpm
; a 16th note is worth 1/4 of a beat
; at modrato, a 16th note is held for 138.8888 ms
Play_Note_Delay:
	Wait_Milli_Seconds(#139)
djnz R2, Play_Note_Delay
ret

Note_Stop:
	clr TR0
	Wait_Milli_Seconds(#50)
	setb TR0
ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;  
Startup:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall InitTimer0
    setb EA
    Set_Cursor(2,1)
    Send_Constant_String(#initial_message1)
	Set_Cursor(1,1)
	Send_Constant_String(#blank_message)
	
forever:
	;lcall Note_Stop
	Play_Note(key_A5, tone_p1a, tone_p1b, #4)	;A5
	Play_Note(key_A5, tone_p1a, tone_p1b, #4)	;A5
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	
	Play_Note(key_A5, tone_ma6a, tone_ma6b,#4)	;F5
	Play_Note(key_A5, tone_ma6a, tone_ma6b,#4)	;F5
	Play_Note(key_A5, tone_p5a, tone_p5b, #8)	;E5
	
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	
	Play_Note(key_A5, tone_ma2a, tone_ma2b, #4)	;B5
	Play_Note(key_A5, tone_ma2a, tone_ma2b, #4)	;B5
	Play_Note(key_A5, tone_p1a, tone_p1b, #8)	;A5
	
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	Play_Note(key_A5, tone_ma2a, tone_ma2b, #8)	;B5
	
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	Play_Note(key_A5, tone_ma2a, tone_ma2b, #8)	;B5
	
	Play_Note(key_A5, tone_p1a, tone_p1b, #4)	;A5
	Play_Note(key_A5, tone_p1a, tone_p1b, #4)	;A5
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	Play_Note(key_A5, tone_p5a, tone_p5b, #4)	;E5
	
	Play_Note(key_A5, tone_ma6a, tone_ma6b,#4)	;F5
	Play_Note(key_A5, tone_ma6a, tone_ma6b,#4)	;F5
	Play_Note(key_A5, tone_p5a, tone_p5b, #8)	;E5
	
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	Play_Note(key_A5, tone_p4a, tone_p4b, #4)	;D5
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	Play_Note(key_A5, tone_ma3a, tone_ma3b, #4)	;C5#
	
	Play_Note(key_A5, tone_ma2a, tone_ma2b, #4)	;B5
	Play_Note(key_A5, tone_ma2a, tone_ma2b, #4)	;B5
	Play_Note(key_A5, tone_p1a, tone_p1b, #8)	;A5
	
	ljmp forever
	
	
	
	
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADFS)
	mov RL0, #low(TIMER0_RELOADFS)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADFS)
	mov RL0, #low(TIMER0_RELOADFS)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADE)
	mov RL0, #low(TIMER0_RELOADE)
	setb TR0
	lcall Note_Stop
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADD)
	mov RL0, #low(TIMER0_RELOADD)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADD)
	mov RL0, #low(TIMER0_RELOADD)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADCS)
	mov RL0, #low(TIMER0_RELOADCS)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADCS)
	mov RL0, #low(TIMER0_RELOADCS)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADB)
	mov RL0, #low(TIMER0_RELOADB)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADB)
	mov RL0, #low(TIMER0_RELOADB)
	setb TR0
	
	lcall Note_Stop
	clr TR0
	
	lcall Note_Stop
	clr TR0
	mov RH0, #high(TIMER0_RELOADA)
	mov RL0, #low(TIMER0_RELOADA)
	setb TR0
	lcall Note_Stop
	
	lcall Note_Stop
	clr TR0
	
    ljmp forever ; Repeat! 

end
