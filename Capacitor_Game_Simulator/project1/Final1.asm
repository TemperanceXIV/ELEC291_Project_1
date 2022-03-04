$NOLIST
$MODLP51
$LIST

org 0000H
   ljmp MyProgram

org 0x000B
	ljmp Timer0_ISR

; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR
	
DSEG at 0x30
x: ds 4
y: ds 4
bcd: ds 5
Period_A: ds 3
Period_B: ds 3
Period_C: ds 3
Period_D: ds 3
T2ov:     ds 1
Seed: ds 4
SeedHolder: ds 4
OnOff: ds 1
Player1Counter: ds 4
Player2Counter: ds 4
Player3Counter: ds 4
PLayer4Counter: ds 4
CurrentFreq: ds 1
bob: ds 2
Once: ds 2

bseg
mf: dbit 1
half_seconds_flag: dbit 1

cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P3.2
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P3.3
LCD_D4 equ P3.4
LCD_D5 equ P3.5
LCD_D6 equ P3.6
LCD_D7 equ P3.7
SOUND_OUT equ p1.1



CLK equ 22118400
TIMER0_RATE equ 4096
TIMER0_RATEA EQU 1580*2
TIMER0_RATEE EQU 2350*2
TIMER0_RATEFS EQU 2600*2
TIMER0_RATED EQU 2100*2
TIMER0_RATECS EQU 2000*2
TIMER0_RATEB EQU 1780*2

TIMER0_RELOAD1 equ ((65536-(CLK/1000)))
TIMER0_RELOAD2 equ ((65536-(CLK/2000)))
TIMER0_RELOADA EQU ((65536-(CLK/TIMER0_RATEA)))
TIMER0_RELOADE EQU ((65536-(CLK/TIMER0_RATEE)))
TIMER0_RELOADFS EQU ((65536-(CLK/TIMER0_RATEFS)))
TIMER0_RELOADD EQU ((65536-(CLK/TIMER0_RATED)))
TIMER0_RELOADCS EQU ((65536-(CLK/TIMER0_RATECS)))
TIMER0_RELOADB EQU ((65536-(CLK/TIMER0_RATEB)))


$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$include(math32.inc)
$LIST

dseg at 0x30
Timer2_overflow: ds 1 ; 8-bit overflow to measure the frequency of fast signals (over 65535Hz)
Counter: ds 2
Counter1: ds 2



cseg
;                       1234567890123456    <- This helps determine the location of the counter
Initial_Message1:  	db 'Period A:       ', 0
Initial_Message2:  	db 'Period B:       ', 0
EndMessage1: 		db 'Player 1 Wins!', 0
EndMessage2: 		db 'Player 2 Wins!', 0
EndMessage3: 		db 'Player 3 Wins!', 0
PL1: 				db 'P1:', 0
PL2: 				db 'P2:', 0
PL3: 				db 'P3:', 0
BlankSpace: 		db '00', 0
BlankRow: 			db '0000000000000000'




;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in ISR.
	inc T2ov
	reti

; When using a 22.1184MHz crystal in fast mode
; one cycle takes 1.0/22.1184MHz = 45.21123 ns
; (tuned manually to get as close to 1s as possible)
Random:

	; Seed = 214013*Seed+2531011
	mov x+0, Seed+0
	mov x+1, Seed+1
	mov x+2, Seed+2
	mov x+3, Seed+3
	Load_y(214013)
	lcall mul32
	Load_y(2531011)
	lcall add32
	mov Seed+0, x+0
	mov Seed+1, x+1
	mov Seed+2, x+2
	mov Seed+3, x+3
	ret
	
Wait_Random:
	lcall Random
	Wait_Milli_Seconds(Seed+0)
	Wait_Milli_Seconds(Seed+1)
	Wait_Milli_Seconds(Seed+2)
	Wait_Milli_Seconds(Seed+3)
	ret
	
Wait1s:
    mov R2, #176
X3: mov R1, #250
X2: mov R0, #166
X1: djnz R0, X1 ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, X2 ; 22.51519us*250=5.629ms
    djnz R2, X3 ; 5.629ms*176=1.0s (approximately)
    ret

;Initializes timer/counter 2 as a 16-bit timer
InitTimer2:
	mov T2CON, #0b_0000_0000 ; Stop timer/counter.  Set as timer (clock input is pin 22.1184MHz).
	; Set the reload value on overflow to zero (just in case is not zero)
	mov RCAP2H, #0
	mov RCAP2L, #0
	setb ET2  ; Enable timer 2 interrupt to count overflow
    ret

;Converts the hex number in T2ov-TH2 to BCD in R2-R1-R0
hex2bcd3:
	clr a
    mov R0, #0  ;Set BCD result to 00000000 
    mov R1, #0
    mov R2, #0
    mov R3, #16 ;Loop counter.

hex2bcd_loop:
    mov a, TH2 ;Shift T2ov-TH2 left through carry
    rlc a
    mov TH2, a
    
    mov a, T2ov
    rlc a
    mov T2ov, a
      
	; Perform bcd + bcd + carry
	; using BCD numbers
	mov a, R0
	addc a, R0
	da a
	mov R0, a
	
	mov a, R1
	addc a, R1
	da a
	mov R1, a
	
	mov a, R2
	addc a, R2
	da a
	mov R2, a
	
	djnz R3, hex2bcd_loop
	ret

; Dumps the 5-digit packed BCD number in R2-R1-R0 into the LCD
DisplayBCD_LCD:
	; 5th digit:
    mov a, R2
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 4th digit:
    mov a, R1
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 3rd digit:
    mov a, R1
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 2nd digit:
    mov a, R0
    swap a
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
	; 1st digit:
    mov a, R0
    anl a, #0FH
    orl a, #'0' ; convert to ASCII
	lcall ?WriteData
    
    ret
    

    
Timer0_Init:
	
	lcall Wait_Random
	lcall Wait_Random
	lcall Wait_Random
	lcall Wait_Random
	lcall Wait_Random
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	lcall Random
	mov SeedHolder+3, Seed+3
	mov a, SeedHolder+3
	mov b, #2
	div ab 
	mov a, b
	cjne a, #0x00, LowFreq
	mov TH0, #high(TIMER0_RELOAD1)
	mov TL0, #low(TIMER0_RELOAD1)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD1)
	mov RL0, #low(TIMER0_RELOAD1)
	mov CurrentFreq, #0x01

	sjmp Donne
LowFreq:
	mov TH0, #high(TIMER0_RELOAD2)
	mov TL0, #low(TIMER0_RELOAD2)
	; Set autoreload value
	mov RH0, #high(TIMER0_RELOAD2)
	mov RL0, #low(TIMER0_RELOAD2)
	mov CurrentFreq, #0x00

Donne:
	
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret
	
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	
	
	cpl SOUND_OUT ; Connect speaker to P1.1!	
	reti
;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
	jb p4.5, $
	
	mov Once, #0x69
    lcall InitTimer2
    lcall Timer0_Init
    lcall LCD_4BIT ; Initialize LCD
    setb EA ; enable interrupts
    setb P2.0 ; Pin is used as input
    setb P2.1 ; Pin is used as input
    setb P0.2
    setb P0.5
    mov OnOff, #0x00
    mov Player1Counter, #0x00
    mov Player2Counter, #0x00
    mov Player3Counter, #0x00
    mov Player4Counter, #0x00
    mov CurrentFreq, #0x00
    Set_Cursor(1,1)
    Send_Constant_String(#PL1)
    Set_Cursor(1,3)
    Send_Constant_String(#PL2)
    Set_Cursor(1,5)
    Send_Constant_String(#PL3)
   
	ret

WaitHalfSec:
	Wait_Milli_Seconds(#100)
	Wait_Milli_Seconds(#100)
	Wait_Milli_Seconds(#100)
	Wait_Milli_Seconds(#100)

ret
Victory_Song2:
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADA)
	mov RL0, #low(TIMER0_RELOADA)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADA)
	mov RL0, #low(TIMER0_RELOADA)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADE)
	mov RL0, #low(TIMER0_RELOADE)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADE)
	mov RL0, #low(TIMER0_RELOADE)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADFS)
	mov RL0, #low(TIMER0_RELOADFS)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADFS)
	mov RL0, #low(TIMER0_RELOADFS)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADE)
	mov RL0, #low(TIMER0_RELOADE)
	setb TR0
	Wait_Milli_Seconds(#50)
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADD)
	mov RL0, #low(TIMER0_RELOADD)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADD)
	mov RL0, #low(TIMER0_RELOADD)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADCS)
	mov RL0, #low(TIMER0_RELOADCS)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADCS)
	mov RL0, #low(TIMER0_RELOADCS)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADB)
	mov RL0, #low(TIMER0_RELOADB)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADB)
	mov RL0, #low(TIMER0_RELOADB)
	setb TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	
	Wait_Milli_Seconds(#50)
	clr TR0
	mov RH0, #high(TIMER0_RELOADA)
	mov RL0, #low(TIMER0_RELOADA)
	setb TR0
	Wait_Milli_Seconds(#50)
	
	Wait_Milli_Seconds(#50)
	clr TR0

ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;  
; Play a song function. Pause the game while active
Victory_Song:
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADA)
	mov RL0, #low(TIMER0_RELOADA)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADA)
	mov RL0, #low(TIMER0_RELOADA)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADE)
	mov RL0, #low(TIMER0_RELOADE)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADE)
	mov RL0, #low(TIMER0_RELOADE)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADFS)
	mov RL0, #low(TIMER0_RELOADFS)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADFS)
	mov RL0, #low(TIMER0_RELOADFS)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADE)
	mov RL0, #low(TIMER0_RELOADE)
	setb TR0
	lcall WaitHalfSec
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADD)
	mov RL0, #low(TIMER0_RELOADD)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADD)
	mov RL0, #low(TIMER0_RELOADD)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADCS)
	mov RL0, #low(TIMER0_RELOADCS)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADCS)
	mov RL0, #low(TIMER0_RELOADCS)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADB)
	mov RL0, #low(TIMER0_RELOADB)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADB)
	mov RL0, #low(TIMER0_RELOADB)
	setb TR0
	
	lcall WaitHalfSec
	clr TR0
	
	lcall WaitHalfSec
	clr TR0
	mov RH0, #high(TIMER0_RELOADA)
	mov RL0, #low(TIMER0_RELOADA)
	setb TR0
	lcall WaitHalfSec
	
	lcall WaitHalfSec
	clr TR0

ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    ; Make sure the two input pins are configure for input
   

;	Set_Cursor(1, 1)
 ;   Display_BCD(Player1Counter)
;	Set_Cursor(2, 1)
  ;  Display_BCD(Player2Counter)
    
forever:
    ; Measure the period applied to pin P2.0


;   lcall Timer0_Init
	mov a, Player1Counter
	cjne a, #0x04, NoWinner1
	ljmp Player1Wins
NoWinner1:
	mov a, Player2Counter
	cjne a, #0x04, NoWinner2
	ljmp Player2Wins
NoWinner2:
	mov a, Player3Counter
	cjne a, #0x04, NoWinner3
	ljmp Player3Wins
NoWinner3:
	mov a, Player4Counter
	cjne a, #0x04, NoWinner4
	ljmp GameOver
NoWinner4:
    clr a
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P1.0, $
    jnb P1.0, $
   mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop1:
 	jb P1.0, $
    jnb P1.0, $

    djnz R0, meas_loop1 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov Period_A+0, TL2
    mov Period_A+1, TH2
    mov Period_A+2, T2ov

	; Convert the result to BCD and display on LCD
;	Set_Cursor(1, 11)
;	lcall hex2bcd3
  ;  lcall DisplayBCD_LCD
   
    
  ;  mov a, Period_A
    mov a, Period_A+1
    
	mov b, #1
	div ab
	add a, #20
	da a
    Set_Cursor(1, 10)
    Display_BCD(a)
    cjne a, #0x53, LA
    mov a, CurrentFreq
    cjne a, #0x00, LB
    inc Player1Counter
    Set_Cursor(1, 1)
    Display_BCD(Player1Counter)
    cpl TR0
    lcall Timer0_Init
    ljmp LD11
LB:
	mov a, Player1Counter
	cjne a, #0x00, LC
	cpl TR0
	lcall Timer0_Init
	ljmp LD11
LC:
	dec Player1Counter
	Set_Cursor(1, 1)
    Display_BCD(Player1Counter)
	cpl TR0
	lcall Timer0_Init
	ljmp LD11
LA:
    
    ; Measure the period applied to pin P2.1
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P2.6, $
    jnb P2.6, $
    mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop2:

   jb P2.6, $
    jnb P2.6, $
    djnz R0, meas_loop2 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov Period_B+0, TL2
    mov Period_B+1, TH2
    mov Period_B+2, T2ov

	; Convert the result to BCD and display on LCD
;	Set_Cursor(2, 11)
	;lcall hex2bcd3
   ; lcall DisplayBCD_LCD
    
    mov a, Period_B+1
    
	mov b, #2
	div ab
	add a, #35
	da a
    Set_Cursor(1, 13)
    Display_BCD(a)

    cjne a, #0x53, LD
    mov a, CurrentFreq
    cjne a, #0x00, LG
    inc Player2Counter
    Set_Cursor(1, 5)
    Display_BCD(Player2Counter)
    cpl TR0
    lcall Timer0_Init
    ljmp LD11  
LG:
	mov a, Player2Counter
	cjne a, #0x00, LF
	cpl TR0
	lcall Timer0_Init
	ljmp LD11
LF:
	dec Player2Counter
	Set_Cursor(1, 5)
    Display_BCD(Player2Counter)
	cpl TR0
	lcall Timer0_Init
	ljmp LD11
LD:
clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P0.2, $
    jnb P0.2, $
    mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop3:

   jb P0.2, $
    jnb P0.2, $
    djnz R0, meas_loop3 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov Period_C+0, TL2
    mov Period_C+1, TH2
    mov Period_C+2, T2ov

	; Convert the result to BCD and display on LCD
;	Set_Cursor(2, 7)
	;lcall hex2bcd3
   ; lcall DisplayBCD_LCD
    
    mov a, Period_C+1
    
	mov b, #2
	div ab
	add a, #10
	da a
    Set_Cursor(2, 10)
    Display_BCD(a)

    cjne a, #0x35, LD1
    mov a, CurrentFreq
    cjne a, #0x00, LG1
    inc Player3Counter
    Set_Cursor(2, 1)
    Display_BCD(Player3Counter)
    cpl TR0
    lcall Timer0_Init
    ljmp LD11
LG1:
	mov a, Player3Counter
	cjne a, #0x00, LF1
	cpl TR0
	lcall Timer0_Init
	ljmp LD11
LF1:
	dec Player3Counter
	Set_Cursor(2, 1)
    Display_BCD(Player3Counter)
	cpl TR0
	lcall Timer0_Init
	ljmp LD11
LD1:

clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P0.5, $
    jnb P0.5, $
    mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop4:

   jb P0.5, $
    jnb P0.5, $
    djnz R0, meas_loop4 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov Period_D+0, TL2
    mov Period_D+1, TH2
    mov Period_D+2, T2ov

	; Convert the result to BCD and display on LCD
;	Set_Cursor(2, 7)
;	lcall hex2bcd3
  ;  lcall DisplayBCD_LCD
    
    mov a, Period_D+1
    
	mov b, #2
	div ab
	add a, #20
	da a
    Set_Cursor(2, 13)
    Display_BCD(a)

    cjne a, #0x45, LD11
    mov a, CurrentFreq
    cjne a, #0x00, LG11
    inc Player4Counter
    Set_Cursor(2, 5)
    Display_BCD(Player4Counter)
    cpl TR0
    lcall Timer0_Init
    sjmp LD11 
LG11:
	mov a, Player4Counter
	cjne a, #0x00, LF11
	cpl TR0
	lcall Timer0_Init
	sjmp LD1
LF11:
	dec Player4Counter
	Set_Cursor(2, 5)
    Display_BCD(Player4Counter)
	cpl TR0
	lcall Timer0_Init
LD11:
    Set_Cursor(1, 1)
    Display_BCD(Player1Counter)
	Set_Cursor(1, 5)
    Display_BCD(Player2Counter)
    Set_Cursor(2, 1)
    Display_BCD(Player3Counter)
	Set_Cursor(2, 5)
    Display_BCD(Player4Counter)

;    mov a, OnOff
;    cjne a, #0x00, Next
 ;   cpl TR0
 ;   inc OnOff
;    sjmp NextTwo
Next:
;	dec OnOff
NextTwo:
    ljmp forever ; Repeat! 

GameOver:
    cpl TR0
	;mov a, Player1Counter
	;cjne a, #0x04, Player2Wins
Player1Wins:
	Set_Cursor(1, 15)
	Send_Constant_String(#BlankSpace)
	Set_Cursor(2, 1)
	Send_Constant_String(#BlankRow)
	Set_Cursor(1, 1)
	Send_Constant_String(#EndMessage1)
	ljmp DeadEnd
Player2Wins:
	
	;mov a, Player2Counter
	;cjne a, #0x04, Player3Wins
	Set_Cursor(1, 15)
	Send_Constant_String(#BlankSpace)
	Set_Cursor(2, 1)
	Send_Constant_String(#BlankRow)
	Set_Cursor(1, 1)
	Send_Constant_String(#EndMessage2)
	ljmp DeadEnd
	
Player3Wins:
	Set_Cursor(1, 15)
	Send_Constant_String(#BlankSpace)
	Set_Cursor(2, 1)
	Send_Constant_String(#BlankRow)
	Set_Cursor(1, 1)
	Send_Constant_String(#EndMessage3)
	
DeadEnd:
    lcall Victory_Song
    lcall Victory_Song2
end
