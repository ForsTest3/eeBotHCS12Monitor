;*****************************************************************
;*COE538 Lab 3
;* 
;* 
;*****************************************************************

; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry                  ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

;*****************************************************************
;* Displaying battery voltage and bumper states (s19c32)         *
;*****************************************************************

;---------------------------------------------------------------
; Definitions
;---------------------------------------------------------------
LCD_DAT     EQU   PORTB          ; LCD data port, bits - PB7,...,PB0
LCD_CNTR    EQU   PTJ            ; LCD control port, bits - PE7(RS),PE4(E)
LCD_E       EQU   $80            ; LCD E-signal pin (bit 7)
LCD_RS      EQU   $40            ; LCD RS-signal pin (bit 6)

;---------------------------------------------------------------
; Variable/data section
;---------------------------------------------------------------
            ORG         $3850

TEN_THOUS   RMB   1              ; 10,000 digit RMB reserve memory byte
THOUSANDS   RMB   1              ;  1,000 digit
HUNDREDS    RMB   1              ;    100 digit
TENS        RMB   1              ;     10 digit
UNITS       RMB   1              ;      1 digit (units digit)

BCD_SPARE   RMB   2              ; Extra space for decimal point and string terminator  (2 bytes total for both)
;. decimal points, and null characters for string terminators

NO_BLANK    RMB   1              ; Used in 'leading zero' blanking by BCD2ASC,    like a switch (finds first non zero number)
;leading zero blanking replaces the zeros with spaces or nothing

;---------------------------------------------------------------
; Code section
;---------------------------------------------------------------
            ORG         $4000

Entry:
_Startup:

            LDS     #$4000               ; Initialize the stack pointer
            JSR     initAD               ; Initialize ATD converter
            JSR     initLCD              ; Initialize LCD
            JSR     clrLCD               ; Clear LCD & home cursor

            LDX     #msg1                ; Display msg1, (gets address msg1 to register X)
            JSR     putsLCD              ;   "
            LDAA    #$C0                 ; Move LCD cursor to the 2nd row, (uses $C0 value directly)
            JSR     cmd2LCD
            LDX     #msg2                ; Display msg2 (register x loaded with address of msg2)
            JSR     putsLCD              ;   "

lbl         MOVB    #$90,ATDCTL5     ; r.just., unsign., sing.conv., mult., ch0, start conv.
            BRCLR   ATDSTAT0,$80,*   ; Wait until the conversion sequence is complete
            
            ;branch if bits are clear, checks if bit 7
            ;if not, branch to * <-- current address

            LDAA    ATDDR4L              ; Load the ch4 result into AccA
            LDAB    #39              ; AccB = 39
            MUL                      ; AccD = 1st result × 39
            ADDD    #600              ; AccD = 1st result × 39 + 600

            JSR     int2BCD
            JSR     BCD2ASC
      
            LDAA    #$8F              ; Move LCD cursor to the 1st row, end of msg1
            ;10001111
            JSR     cmd2LCD

            LDAA    TEN_THOUS        ; Output the TEN_THOUS ASCII character
            JSR     putcLCD
        
            LDAA    THOUSANDS        ; Same for THOUSANDS, '.' and HUNDREDS
            JSR     putcLCD
        
            LDAA    #'.'
            JSR     putcLCD    
        
            LDAA    HUNDREDS
            JSR     putcLCD      

            LDAA    #$CF              ; Move LCD cursor to the 2nd row, end of msg2
            ;11001111
            JSR     cmd2LCD

            ;function as switches overall to ensure code is within bounds
            
            BRCLR   PORTAD0,%00000100,bowON ; Check bow switch
            ;branch to bowON if bit is clear (bit 2), otherwise continue 
            
            LDAA    #$31             ; Output '1' if bow sw OFF, ascii
            BRA     bowOFF

bowON       LDAA    #$30             ; Output '0' if bow sw ON , ascii range
bowOFF      JSR     putcLCD           ;for display, either 1s or 0s accordingly

            LDAA    #' '              ; Output a space character in ASCII

            BRCLR   PORTAD0,%00001000,sternON ; Check stern switch
            LDAA    #$31             ; Output '1' if stern sw OFF
            BRA     sternOFF

sternON     LDAA    #$30             ; Output '0' if stern sw ON  ascii 0 
sternOFF    JSR    putcLCD

            JMP     lbl              ; Loop forever

;---------------------------------------------------------------
; Messages
;---------------------------------------------------------------
msg1        dc.b   "Battery volt ",0
msg2        dc.b   "Sw status ",0

;---------------------------------------------------------------
; Subroutine section
;---------------------------------------------------------------
initLCD     BSET    DDRB,%11111111        ; Configure pins PS7, PS6, PS5, PS4 for output (LCD data lines)
            BSET    DDRJ,%11000000        ; Configure pins PE7 (RS) and PE4 (E) for output
            LDY     #2000                 ; Wait for LCD to be ready, set 2000 for ideal place
            JSR     del_50us              ; Delay ~2000 × 50 µs = 0.1 s total
                                                                                       
            LDAA    #$28                  ; Set 4-bit data mode, 2-line display, 5x8 font  ()
            JSR     cmd2LCD

            LDAA    #$0C                  ; Display ON, cursor OFF, blinking OFF
            JSR     cmd2LCD

            LDAA    #$06                  ; Move cursor right after entering a character
            JSR     cmd2LCD
            
            RTS                           ; Return from subroutine
 
 
clrLCD      LDAA  #$01            ; clear cursor and return to home position
            JSR   cmd2LCD         ; -"-
            LDY   #40             ; wait until "clear cursor" command is complete
            JSR   del_50us        ; -"-
            RTS
            
del_50us:   PSHX                  ;2 E-clk                      ;delay loop
eloop:      LDX   #40             ;2 E-clk -
iloop:      PSHA                  ;2 E-clk |   2
            PULA                  ;3 E-clk |   5
            
            PSHA                  ;2 E-clk     7
            PULA                  ;3 E-clk     10
            PSHA                  ;2 E-clk     12
            PULA                  ;3 E-clk     15
            PSHA                  ;2 E-clk     17
            PULA                  ;3 E-clk     20
                                  ;        |
            PSHA                  ;2 E-clk | 50us 22
            PULA                  ;3 E-clk |      25
            NOP                   ;1 E-clk |      26
            NOP                   ;1 E-clk |      27
            DBNE  X,iloop         ;3 E-clk -      30
            DBNE  Y,eloop         ;3 E-clk
            PULX                  ;3 E-clk
            RTS                   ;5 E-clk

cmd2LCD:    BCLR  LCD_CNTR,LCD_RS ; select the LCD Instruction Register (IR)
            JSR   dataMov         ; send data to IR
            RTS
              
putsLCD     LDAA  1,X+            ; get one character from the string, loads from the address value X+1,then increments by 1
            BEQ   donePS          ; reach NULL character? branch if equal
            JSR   putcLCD ;jump to select data register
            BRA   putsLCD ; jumps back
donePS      RTS

putcLCD     BSET  LCD_CNTR,LCD_RS ; select the LCD Data register (DR)
            JSR   dataMov         ; send data to DR
            RTS
            
dataMov     BSET  LCD_CNTR,LCD_E  ; pull the LCD E-sigal high (cntr controls e pin voltage)
            STAA  LCD_DAT         ; send the upper 4 bits of data to LCD
            BCLR  LCD_CNTR,LCD_E  ; pull the LCD E-signal low to complete the write oper.(specific bits to 0)
            
            LSLA                  ; match the lower 4 bits with the LCD data pins
            LSLA                  ; -"-
            LSLA                  ; -"-
            LSLA                  ; -"-
            
            BSET  LCD_CNTR,LCD_E  ; pull the LCD E signal high
            STAA  LCD_DAT         ; send the lower 4 bits of data to LCD
            BCLR  LCD_CNTR,LCD_E  ; pull the LCD E-signal low to complete the write oper.
            
            ;this gets all 8 after, and allows for pulsing from E signal
            
            LDY   #1              ; adding this delay will complete the internal
            JSR   del_50us        ; operation for most instructions
            RTS
            ;delay to prevent data being sent too fast before process

            
int2BCD     XGDX                  ;Save the binary number into .X, exchange D with X
            LDAA  #0              ;Clear the BCD_BUFFER, loads 0 into A keeping it empty
            STAA  TEN_THOUS
            STAA  THOUSANDS        ;rest here stores digits
            STAA  HUNDREDS
            STAA  TENS
            STAA  UNITS
            STAA  BCD_SPARE
            STAA  BCD_SPARE+1      ;next byte over

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
            ;takes the digits of the binary value into the register

CON_EXIT    RTS                   ;We’re done the conversion    simply return


BCD2ASC     LDAA  #0              ;Initialize the blanking flag, 0 into accumulator A
            STAA  NO_BLANK        ;blanks it

;segment ten thousand
C_TTHOU     LDAA  TEN_THOUS       ;Check the ’ten_thousands’ digit
            ORAA  NO_BLANK        ;check if non zero
            BNE   NOT_BLANK1      ;branch if not equal to 0,

ISBLANK1    LDAA  #' '            ;goes to isblank1, set blank
            STAA  TEN_THOUS       ;so store a space
            BRA   C_THOU          ;and check the ’thousands’ digit, goes to thousands

NOT_BLANK1  LDAA  TEN_THOUS       ;Get the ’ten_thousands’ digit
            ORAA  #$30            ;Convert to ascii
            STAA  TEN_THOUS
            LDAA  #$1             ;Signal that we have seen a ’non-blank’ digit
            STAA  NO_BLANK

;segment thousands
C_THOU      LDAA  THOUSANDS       ;Check the thousands digit for blankness
            ORAA  NO_BLANK        ;If it’s blank and ’no-blank’ is still zero
            BNE   NOT_BLANK2

ISBLANK2    LDAA  #' '            ;Thousands digit is blank
            STAA  THOUSANDS       ;so store a space
            BRA   C_HUNS          ;and check the hundreds digit

NOT_BLANK2  LDAA  THOUSANDS       ;(similar to ’ten_thousands’ case)
            ORAA  #$30
            STAA  THOUSANDS
            LDAA  #$1
            STAA  NO_BLANK

;segment hundreds
C_HUNS      LDAA  HUNDREDS        ;Check the hundreds digit for blankness
            ORAA  NO_BLANK        ;If it’s blank and ’no-blank’ is still zero, 
            BNE   NOT_BLANK3


ISBLANK3    LDAA  #' '            ;Hundreds digit is blank
            STAA  HUNDREDS        ;so store a space
            BRA   C_TENS          ;and check the tens digit


NOT_BLANK3  LDAA  HUNDREDS        ;(similar to ’ten_thousands’ case but for blanks)
            ORAA  #$30
            STAA  HUNDREDS
            LDAA  #$1
            STAA  NO_BLANK
            
;segment tens
C_TENS      LDAA  TENS            ;Check the tens digit for blankness
            ORAA  NO_BLANK        ;If it’s blank and ’no-blank’ is still zero
            BNE   NOT_BLANK4

ISBLANK4    LDAA  #' '            ;Tens digit is blank
            STAA  TENS            ;so store a space
            BRA   C_UNITS         ;and check the units digit

NOT_BLANK4  LDAA  TENS            ;(similar to ’ten_thousands’ case)
            ORAA  #$30            ;cleaning up makes it so 00345 becomes 345
            STAA  TENS

;units
C_UNITS     LDAA  UNITS           ;No blank check necessary, convert to ascii. loads units value
            ORAA  #$30            ;OR to convert ascii, retains the 1s necessary
            STAA  UNITS           ;store back into units
            RTS                   ;We’re done

;move according values to each part, this is to 
initAD      MOVB   #$C0,ATDCTL2  ; Power up AD, select fast flag clear (11000000)
            JSR    del_50us       ; Wait for 50 µs
            MOVB   #$00,ATDCTL3  ; 8 conversions in a sequence  (all 0s)
            MOVB   #$85,ATDCTL4  ; res=8, conv-clks=2, prescal=12     (10000101)  (specific value for pins)
            BSET   ATDDIEN,$0C   ; Configure pins AN03,AN02 as digital inputs, bit set with $0c in binary (00001100) 
            RTS

;---------------------------------------------------------------
; Interrupt vectors
;---------------------------------------------------------------
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector
