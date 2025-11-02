;*****************************************************************
;*                                                               *
;* Lab 5: Robot Roaming Program (9S32C)                          *
;*                                                               *
;*                                                               *
;*****************************************************************

; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point



; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 
		

; equates section
;*******************************************************************
LCD_DAT      EQU    PORTB   ; LCD data port, bits - PB7,...,PB0
LCD_CNTR     EQU    PTJ     ; LCD control port, bits - PJ7(E),PJ6(RS)
LCD_E        EQU    $80     ; LCD E-signal pin (bit 7)
LCD_RS       EQU    $40     ; LCD RS-signal pin (bit 6)  ;from lab4
FWD_INT      EQU    69      ; 3 second delay (at 23Hz)  23*3
REV_INT      EQU    69      ; 3 second delay (at 23Hz)
FWD_TRN_INT  EQU    46      ; 2 second delay (at 23Hz)  23 * 2
REV_TRN_INT  EQU    46      ; 2 second delay (at 23Hz)

START        EQU    0       ;list of states with their values, dispatcher will loop
FWD          EQU    1
REVERSE      EQU    2
ALL_STP      EQU    3
FWD_TRN      EQU    4
REV_TRN      EQU    5

; variable section

            ORG    $3850    ; Where our TOF counter register lives
TOF_COUNTER dc.b   0        ; The timer, incremented at 23Hz
CRNT_STATE  dc.b   3        ; Current state register
T_FWD       ds.b   1        ; FWD time
T_REV       ds.b   1        ; REV time
T_FWD_TRN   ds.b   1        ; FWD_TURN time
T_REV_TRN   ds.b   1        ; REV_TURN time

;data code for voltage display
TEN_THOUS   ds.b   1        ; 10,000 digit
THOUSANDS   ds.b   1        ; 1,000 digit
HUNDREDS    ds.b   1        ; 100 digit
TENS        ds.b   1        ; 10 digit
UNITS       ds.b   1        ; 1 digit
NO_BLANK    ds.b   1        ; Used in 'leading zero' blanking by BCD2ASC
BCD_SPARE   ds.b   2

; code section

            ORG    $4000    ; Where the code starts, initialization

Entry:    
_Startup:   
            CLI              ; Enable interrupts |
            LDS    #$4000   ; Initialize the stack pointer
         
            BSET   DDRA,%00000011 ; STAR_DIR, PORT_DIR N
            BSET   DDRT,%00110000 ; STAR_SPEED, PORT_SPEED I
          
            JSR    initAD    ; Initialize ATD converter I
            
            JSR    initLCD   ; Initialize the LCD L
            JSR    clrLCD    ; Clear LCD & home cursor I
       
            LDX    #msg1     ; Display msg1 A
            JSR    putsLCD   ; " T
           
            LDAA   #$C0      ; Move LCD cursor to the 2nd row O
            JSR    cmd2LCD   ; N
            LDX    #msg2     ; Display msg2 |
            JSR    putsLCD   ; " |
         
            JSR    ENABLE_TOF ; Jump to TOF initialization

MAIN:       JSR    UPDT_DISPL ;Main
            LDAA   CRNT_STATE 
            JSR    DISPATCHER 
            BRA    MAIN      

; data section

msg1        dc.b   "Battery volt",0
msg2        dc.b   "State",0
tab         dc.b   "START ",0
            dc.b   "FWD ",0
            dc.b   "REVERSE ",0
            dc.b   "ALL_STP",0
            dc.b   "FWD_TRN",0
            dc.b   "REV_TRN",0


;**********************************************************************
;* State Dispatcher
;* This routine calls the appropriate state handler based on the current
;* state.
;*
;* Input:  Current state in ACCA
;* Returns: None  
;* Clobbers: Everything
;* State Dispatcher
;**********************************************************************
DISPATCHER:
            CMPA   #START
            BNE    NOT_START
            JSR    START_ST
            BRA    DISP_EXIT

NOT_START:
            CMPA   #FWD
            BNE    NOT_FWD
            JSR    FWD_ST
            BRA    DISP_EXIT

;*********************************************************
NOT_FWD:
            CMPA   #REVERSE
            BNE    NOT_REV
            JSR    REV_ST
            BRA    DISP_EXIT

NOT_REV:
            CMPA   #ALL_STP
            BNE    NOT_ALL_STP
            JSR    ALL_STP_ST
            BRA    DISP_EXIT

NOT_ALL_STP:
            CMPA   #FWD_TRN
            BNE    NOT_FWD_TRN
            JSR    FWD_TRN_ST
            BRA    DISP_EXIT
;*********************************************************
;if not all needed, we can remove not all stop, not rev, not fwd,

NOT_FWD_TRN:
            CMPA   #REV_TRN
            BNE    NOT_REV_TRN
            JSR    REV_TRN_ST
            BRA    DISP_EXIT
            
 
NOT_REV_TRN:
            SWI              ; Undefined state - stop

DISP_EXIT:
            RTS
            
;state handlers
;*****************************************************************
START_ST:
            BRCLR  PORTAD0,$04,NO_FWD  ; If /FWD_BUMP
            JSR    INIT_FWD              ;<-- check code for this
            MOVB   #FWD,CRNT_STATE
            BRA   START_EXIT

NO_FWD:     
            NOP              ; Else
START_EXIT: 
            RTS              ; return to the MAIN routine

;*****************************************************************
FWD_ST:
            ; Check for FWD_BUMP
            BRSET  PORTAD0,$04,NO_FWD_BUMP   ; If FWD_BUMP then
            JSR    INIT_REV                  ; initialize the REVERSE routine
            MOVB   #REVERSE,CRNT_STATE           ; set the state to REVERSE
            BRA    FWD_EXIT                  ; and return

NO_FWD_BUMP:
            ; Check for REAR_BUMP  
            BRSET  PORTAD0,$08,NO_REAR_BUMP  ; If REAR_BUMP then
            JSR    INIT_ALL_STP              ; initialize the ALL_STOP state
            MOVB   #ALL_STP,CRNT_STATE       ; set the state to ALL_STOP
            BRA    FWD_EXIT                  ; and return

NO_REAR_BUMP:
            ; Check if timer expired for FWD_TURN
            LDAA   TOF_COUNTER               ; If Tc > Tfwd then
            CMPA   T_FWD                     ; the robot should make a turn
            BNE    NO_FWD_TURN               ; so
            JSR    INIT_FWD_TRN              ; initialize the FORWARD_TURN state
            MOVB   #FWD_TRN,CRNT_STATE       ; and go to that state
            BRA    FWD_EXIT                  ; and return

NO_FWD_TURN:
            NOP                              ; Else stay in FWD state

FWD_EXIT:   
            RTS                              ; return to the MAIN routine

;*****************************************************************
REV_ST:     
            LDAA   TOF_COUNTER ; If Tc > Trev then
            CMPA   T_REV     ; the robot should make a FWD turn
            BNE    NO_REV_TRN ; so
            JSR    INIT_REV_TRN ; initialize the REV_TRN state
            MOVB   #REV_TRN,CRNT_STATE ; set state to REV_TRN
            BRA    REV_EXIT  ; and return
NO_REV_TRN: 
            NOP              ; Else
REV_EXIT:   
            RTS              ; return to the MAIN routine

;*****************************************************************
ALL_STP_ST: 
            BRSET  PORTAD0,$04,NO_START ; If FWD_BUMP
            BCLR   PTT,%00110000 ; initialize the START state (both motors off)
            MOVB   #START,CRNT_STATE ; set the state to START
            BRA    ALL_STP_EXIT ; and return
NO_START:   
            NOP              ; Else
ALL_STP_EXIT:
            RTS              ; return to the MAIN routine

;*****************************************************************
FWD_TRN_ST: 
            LDAA   TOF_COUNTER ; If Tc > Tfwdturn then
            CMPA   T_FWD_TRN ; the robot should go FWD
            BNE    NO_FWD_FT ; so
            JSR    INIT_FWD  ; initialize the FWD state
            MOVB   #FWD,CRNT_STATE ; set state to FWD
            BRA    FWD_TRN_EXIT ; and return
NO_FWD_FT:  
            NOP              ; Else
FWD_TRN_EXIT:
            RTS              ; return to the MAIN routine

;*****************************************************************
REV_TRN_ST: 
            LDAA   TOF_COUNTER ; If Tc > Trevturn then
            CMPA   T_REV_TRN ; the robot should go FWD
            BNE    NO_FWD_RT ; so
            JSR    INIT_FWD  ; initialize the FWD state
            MOVB   #FWD,CRNT_STATE ; set state to FWD
            BRA    REV_TRN_EXIT ; and return
NO_FWD_RT:  
            NOP              ; Else
REV_TRN_EXIT:
            RTS              ; return to the MAIN routine

 ;*****************************************************************
INIT_FWD:   
            BCLR   PORTA,%00000011 ; Set FWD direction for both motors
            BSET   PTT,%00110000 ; Turn on the drive motors
            LDAA   TOF_COUNTER ; Mark the fwd time Tfwd
            ADDA   #FWD_INT
            STAA   T_FWD
            RTS

;*****************************************************************
INIT_REV:   
            BSET   PORTA,%00000011 ; Set REV direction for both motors
            BSET   PTT,%00110000 ; Turn on the drive motors
            LDAA   TOF_COUNTER ; Mark the fwd time Tfwd
            ADDA   #REV_INT
            STAA   T_REV
            RTS

;*****************************************************************
INIT_ALL_STP:
            BCLR   PTT,%00110000 ; Turn off the drive motors
            RTS

;*****************************************************************
INIT_FWD_TRN:
            BSET   PORTA,%00000010 ; Set REV dir. for STARBOARD (right) motor
            LDAA   TOF_COUNTER ; Mark the fwd_turn time Tfwdturn
            ADDA   #FWD_TRN_INT
            STAA   T_FWD_TRN
            RTS

;*****************************************************************
INIT_REV_TRN:
            BCLR   PORTA,%00000010 ; Set FWD dir. for STARBOARD (right) motor
            LDAA   TOF_COUNTER ; Mark the fwd time Tfwd
            ADDA   #REV_TRN_INT
            STAA   T_REV_TRN
            RTS

; utility subroutines
;*****************************************************************
;* init of LCD: 4-bit data width, 2 line display, turn on display,
;* cursor and blinking off. shift cursor right.
;*****************************************************************
initLCD:
            BSET  DDRB,%11111111            ; configure pins PB7,...,PB0 for output
            BSET  DDRJ,%11000000   ; configure pins PE7, PE4 for output
            LDY   #2000             ; wait for LCD to be ready
            JSR   del_50us          ; -"-
            LDAA  #$28              ; set 4 bit data, 2 line display (specific value)
            JSR   cmd2LCD           ; -"-
            LDAA  #$0C              ; display on, cursor off, blinking off (specific value)
            JSR   cmd2LCD           ; -"-
            LDAA  #$06              ; move cursor right after entering character (specific value)
            JSR   cmd2LCD           ; -"- call each time to send the values
            RTS


;*****************************************************************
;* Clear display and home cursor                                 *
;*****************************************************************
clrLCD:
            LDAA  #$01              ; clear cursor and return to home position, sets for commands
            JSR   cmd2LCD           ; -"-  call to send
            LDY   #40             ; wait until "clear cursor" command is complete
            JSR   del_50us          ; -"-
            RTS


;*****************************************************************
;* ([Y] x 50us) - delay subroutine, E-clk=41.67ns.              *
;*****************************************************************
del_50us:
            PSHX                    ; 2 E-clk   saves the value x has onto stack
            
            ;50 us / 41.67ns = around 1200 e clk
            
       ;1 inner loop iteration = LDX #30 (30) * iloop (40) = 1200      
       
       ;1 outer loop = 1200 + ldx(2) + dbne (3)  = 1205 
       ;adding remaining times = 1205 + pshx(2) + pulx(3) + rts (5) =1215
       ; 1215 * 41.67 ns = 50.62905 us
       
eloop:      LDX   #300              ; 2 E-clk     load 30 into register X
iloop:                         
            NOP                     ; 1 E-clk         37
            DBNE  X,iloop           ; 3 E-clk  inclusive 40.decrement X != 0, and go back to iloop
            DBNE  Y,eloop           ; 3 E-clk  decrement and brach if not equal to zero, Y (20000) * total
            PULX                    ; 3 E-clk  restores saved value back to x
            RTS                     ; 5 E-clk  return from subroutine (pulls return address)


;*****************************************************************
;* this function sends command in accumulator A to LCD           *
;*****************************************************************
cmd2LCD:
            BCLR  LCD_CNTR, LCD_RS  ; select LCD instruction register (IR)
            JSR   dataMov            ; send data to IR
            RTS


;*****************************************************************
;* this function outputs a NULL-terminated string pointed to by X*
;*****************************************************************
putsLCD:
            LDAA  1,X+              ; get one character from string, increment X
            BEQ   donePS             ; reach null character, branch to donePS if = 0
            JSR   putcLCD             ;jump to sub routine putcLCD
            BRA   putsLCD            ;branch always putsLCD, until no characters 
donePS:     RTS

;*****************************************************************
;* this function sends data character in accumulator A to LCD    *
;*****************************************************************
putcLCD:
            BSET  LCD_CNTR, LCD_RS   ; select LCD data register (DR)
            JSR   dataMov            ; send data to DR
            RTS

;*****************************************************************
;* this function sends data to LCD IR or DR depending on RS      *
;*****************************************************************
dataMov:
            BSET  LCD_CNTR, LCD_E    ; pull LCD E-signal high, (goes to LCD_CNTR to perform bitwise OR on LCD_E values)
            STAA  LCD_DAT            ; send upper 4 bits of data to LCD (STARTS UPPER)
            BCLR  LCD_CNTR, LCD_E    ; pull LCD E-signal low to complete write operation (goes to CNTR to perform bitwise AND
            ;on LCD_E values)

            LSLA                     ; match lower 4 bits with LCD data pins, left shift
            LSLA                     ; -"-
            LSLA                     ; -"-
            LSLA                     ; -"-       4 lower bits into 4 upper bits to read in pins

            BSET  LCD_CNTR, LCD_E    ; pull LCD E signal high
            STAA  LCD_DAT            ; send lower 4 bits of data to LCD  (LOWER FROM SHIFTS)
            BCLR  LCD_CNTR, LCD_E    ; pull LCD E-signal low to complete write operation

            LDY   #1                 ; adding delay to complete internal, allow processing
            JSR   del_50us           ; operation for most instructions
            RTS


;move according values to each part, this is to 
initAD      MOVB   #$C0,ATDCTL2  ; Power up AD, select fast flag clear (11000000)
            JSR    del_50us       ; Wait for 50 µs
            MOVB   #$00,ATDCTL3  ; 8 conversions in a sequence  (all 0s)
            MOVB   #$85,ATDCTL4  ; res=8, conv-clks=2, prescal=12     (10000101)  (specific value for pins)
            BSET   ATDDIEN,$0C   ; Configure pins AN03,AN02 as digital inputs, bit set with $0c in binary (00001100) 
            RTS


int2BCD     XGDX                  ;Save the binary number into .X, exchange D with X
            LDAA  #0              ;Clear the BCD_BUFFER, loads 0 into A keeping it empty
            STAA  TEN_THOUS
            STAA  THOUSANDS        ;rest here stores digits
            STAA  HUNDREDS
            STAA  TENS
            STAA  UNITS            
            STAA  BCD_SPARE
            STAA  BCD_SPARE+1

            CPX   #0              ;Check for a zero input (compares if equal)
            BEQ   CON_EXIT        ;and if so, exit (branch if equal to CON_EXIT)

            XGDX                  ;Not zero, get the binary number back to .D as dividend (swaps D and X register values)
            LDX   #10             ;Setup 10 (Decimal!) as the divisor (loads value 10 into register X)
            IDIV                  ;Divide: Quotient is now in .X, remainder in .D , always divides X/D
            STAB  UNITS           ;Store remainder (store accumulator B)
            CPX   #0              ;If quotient is zero,
            BEQ   CON_EXIT        ;then exit

            XGDX                  ;else swap first quotient back into .D
            LDX   #10             ;and setup for another divide by 10
            IDIV                   ;always divides X/D
            STAB  TENS
            CPX   #0
            BEQ   CON_EXIT

            XGDX                  ;Swap quotient back into .D
            LDX   #10             ;and setup for another divide by 10
            IDIV
            STAB  HUNDREDS
            CPX   #0
            BEQ   CON_EXIT

            XGDX                  ;Swap quotient back into .D
            LDX   #10             ;and setup for another divide by 10
            IDIV
            STAB  THOUSANDS
            CPX   #0
            BEQ   CON_EXIT

            XGDX                  ;Swap quotient back into .D
            LDX   #10             ;and setup for another divide by 10
            IDIV
            STAB  TEN_THOUS
            
            ;do for each one to store each digit in register
            ;takes the digits of the binary value into the reg
CON_EXIT    RTS                   ;We’re done the conversion 


;*****************************************************************
;* Convert BCD to ASCII with leading zero blanking
;* Input: BCD digits in TEN_THOUS, THOUSANDS, HUNDREDS, TENS, UNITS
;* Output: ASCII characters in same variables
;*****************************************************************
BCD2ASC:    
            LDAA   #0              ; Initialize the blanking flag
            STAA   NO_BLANK        ; 

; Ten thousands digit
C_TTHOU:    LDAA   TEN_THOUS       ; Check the ten_thousands digit
            ORAA   NO_BLANK        ; Check if non-zero
            BNE    NOT_BLANK1      ; Branch if not equal to 0
ISBLANK1:   LDAA   #' '            ; Blank - store a space
            STAA   TEN_THOUS       ; 
            BRA    C_THOU          ; Check thousands digit
NOT_BLANK1: LDAA   TEN_THOUS       ; Get the ten_thousands digit
            ORAA   #$30            ; Convert to ASCII
            STAA   TEN_THOUS       ; 
            LDAA   #$1             ; Signal non-blank digit seen
            STAA   NO_BLANK        ; 

; Thousands digit
C_THOU:     LDAA   THOUSANDS       ; Check thousands digit
            ORAA   NO_BLANK        ; 
            BNE    NOT_BLANK2      ; 
ISBLANK2:   LDAA   #' '            ; Blank - store space
            STAA   THOUSANDS       ; 
            BRA    C_HUNS          ; Check hundreds digit
NOT_BLANK2: LDAA   THOUSANDS       ; 
            ORAA   #$30            ; Convert to ASCII
            STAA   THOUSANDS       ; 
            LDAA   #$1             ; 
            STAA   NO_BLANK        ; 

; Hundreds digit
C_HUNS:     LDAA   HUNDREDS        ; Check hundreds digit
            ORAA   NO_BLANK        ; 
            BNE    NOT_BLANK3      ; 
ISBLANK3:   LDAA   #' '            ; Blank - store space
            STAA   HUNDREDS        ; 
            BRA    C_TENS          ; Check tens digit
NOT_BLANK3: LDAA   HUNDREDS        ; 
            ORAA   #$30            ; Convert to ASCII
            STAA   HUNDREDS        ; 
            LDAA   #$1             ; 
            STAA   NO_BLANK        ; 

; Tens digit
C_TENS:     LDAA   TENS            ; Check tens digit
            ORAA   NO_BLANK        ; 
            BNE    NOT_BLANK4      ; 
ISBLANK4:   LDAA   #' '            ; Blank - store space
            STAA   TENS            ; 
            BRA    C_UNITS         ; Check units digit
NOT_BLANK4: LDAA   TENS            ; 
            ORAA   #$30            ; Convert to ASCII
            STAA   TENS            ; 

; Units digit (always display)
C_UNITS:    LDAA   UNITS           ; No blank check for units
            ORAA   #$30            ; Convert to ASCII
            STAA   UNITS           ; 
            RTS                    ; Done

;*****************************************************************
;* Timer Functions                                              *
;*****************************************************************

;figure 3 code
; Enable Timer Overflow Function
ENABLE_TOF:
            MOVB    #0, TOF_COUNTER ; Initialize counter to 0 so no random delay times
            LDAA    #%10000000      ; Enable TCNT timer
            STAA    TSCR1           ; Store to Timer System Control Register 1
            LDAA    #%10000000      ; Prepare to clear TOF flag
            STAA    TFLG2           ; Clear Timer Overflow Flag
            
            LDAA    #%10000100      ; Enable TOI interrupt + prescale factor = 16
            STAA    TSCR2           ; Store to Timer System Control Register 2
            RTS     ;return via rts

; Timer Overflow Interrupt Service Routine
TOF_ISR:
            INC     TOF_COUNTER     ; Increment timer counter
            LDAA    #%10000000      ; Prepare to clear TOF flag
            STAA    TFLG2           ; Clear Timer Overflow Flag
            RTI
; Disable Timer Overflow Function
DISABLE_TOF:
            LDAA    #%00000100      ; Disable TOI, keep prescale factor at 16
            STAA    TSCR2           ; Store to Timer System Control Register 2
            RTS
            

;*******************************************************************
;* Update Display (Battery Voltage + Current State)
;*
;*******************************************************************
UPDT_DISPL: 
            MOVB   #$90,ATDCTL5 ; R-just., uns., sing. conv., mult., ch=0, start
            BRCLR  ATDSTAT0,$80,* ; Wait until the conver. seq. is complete
            LDAA   ATDDR0L   ; Load the ch0 result - battery volt - into A
                ; Convert ADC value to voltage display (0-5V scale)
            ; Assuming 8-bit ADC (0-255) represents 0-5V
            ; Multiply by 5000/255 ˜ 19.6 to get millivolts
            LDAB   #39              ; Approximation factor for conversion
            MUL                     ; D = A * B (ADC value * 20)
            ADDD   #600
            ; Convert to BCD for display
            JSR    int2BCD          ; Convert binary in D to BCD digits
            
            ; Convert BCD to ASCII with leading zero blanking
            JSR    BCD2ASC          ; Convert to ASCII characters
            
            ; Display battery voltage on first row
            LDAA   #$8D             ; Position cursor after "Battery volt" text
            JSR    cmd2LCD          ; Move cursor to position
            
            ; Display voltage digits with decimal point
            LDAA   TEN_THOUS        ; Ten thousands digit
            JSR    putcLCD          ; Display digit/space
            
            LDAA   THOUSANDS        ; Thousands digit  
            JSR    putcLCD          ; Display digit/space
            
            LDAA   #$2E
            JSR    putcLCD  
            LDAA   HUNDREDS         ; Hundreds digit (volts)
            JSR    putcLCD          ; Display digit
            

            LDAA   TENS             ; Tens digit (tenths of volts)
            JSR    putcLCD          ; Display digit
            
            
            LDAA   #$C6      ; Move LCD cursor to the 2nd row, end of msg2
            JSR    cmd2LCD   ; Display current state
            LDAB   CRNT_STATE
            LSLB
            LSLB
            LSLB
            LDX    #tab
            ABX
            JSR    putsLCD
            RTS

; Interrupt Vectors
;*******************************************************************
            ORG    $FFFE
            DC.W   Entry
            ORG    $FFDE
            DC.W   TOF_ISR
