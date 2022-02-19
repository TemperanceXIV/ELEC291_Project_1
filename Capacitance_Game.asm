$NOLIST
$MODLP51
$LIST

; Copying from ISR Example 
; Because Timer 2 is being used to measure the capacitors, it auto-reloads to zero.
CLK           	EQU 22118400 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   	EQU 932     ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD 	EQU ((65536-(CLK/TIMER0_RATE)))
SOUND_OUT 		equ P1.1


org 0000H
   ljmp MyProgram

; Timer 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

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

DSEG at 0x30
Period_A: ds 3
Period_B: ds 3
T2ov:     ds 1

CSEG
;                      1234567890123456    <- This helps determine the location of the counter
Initial_Message1:  db 'Period A:       ', 0
Initial_Message2:  db 'Period B:       ', 0


;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
InitTimer0:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
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
	;clr TF0  ; According to the data sheet this is done for us already.
	cpl SOUND_OUT ; Connect speaker to P1.1!
	reti

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
hex2bcd2:
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

;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    lcall InitTimer2
    lcall InitTimer0
    lcall LCD_4BIT ; Initialize LCD
    setb EA ; enable interrupts
	ret

;---------------------------------;
; Main program loop               ;
;---------------------------------;
MyProgram:
    ; Initialize the hardware:
    mov SP, #7FH
    lcall Initialize_All
    ; Make sure the two input pins are configure for input
    setb P2.0 ; Pin is used as input
    setb P2.1 ; Pin is used as input

	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message1)
	Set_Cursor(2, 1)
    Send_Constant_String(#Initial_Message2)
    
forever:
    ; Measure the period applied to pin P2.0
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P2.0, $
    jnb P2.0, $
    mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop1:
    jb P2.0, $
    jnb P2.0, $
    djnz R0, meas_loop1 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.0 for later use
    mov Period_A+0, TL2
    mov Period_A+1, TH2
    mov Period_A+2, T2ov

	; Convert the result to BCD and display on LCD
	Set_Cursor(1, 11)
	lcall hex2bcd2
    lcall DisplayBCD_LCD
    
    ; Measure the period applied to pin P2.1
    clr TR2 ; Stop counter 2
    mov TL2, #0
    mov TH2, #0
    mov T2ov, #0
    jb P2.1, $
    jnb P2.1, $
    mov R0, #0 ; 0 means repeat 256 times
    setb TR2 ; Start counter 0
meas_loop2:
    jb P2.1, $
    jnb P2.1, $
    djnz R0, meas_loop2 ; Measure the time of 100 periods
    clr TR2 ; Stop counter 2, TH2-TL2 has the period
    ; save the period of P2.1 for later use
    mov Period_B+0, TL2
    mov Period_B+1, TH2
    mov Period_B+2, T2ov
    ; AAH so setting an overflow counter byte, it is easilly concatnated to the rest of the timer.

	; Convert the result to BCD and display on LCD
	Set_Cursor(2, 11)
	lcall hex2bcd2
    lcall DisplayBCD_LCD
    
    sjmp forever ; Repeat! 
end