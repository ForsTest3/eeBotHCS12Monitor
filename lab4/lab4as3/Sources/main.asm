;*****************************************************************
;* This stationery serves as the framework for a                 *
;* user application (single file, absolute assembly application) *
;* For a more comprehensive program that                         *
;* demonstrates the more advanced functionality of this          *
;* processor, please see the demonstration applications          *
;* located in the examples subdirectory of the                   *
;* Freescale CodeWarrior for the HC12 Program directory          *
;*****************************************************************

; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point



; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

;************************************************************
;* Timer Alarms                                            *
;************************************************************

;*****************************************************************
;* Definitions                                                  *
;*****************************************************************
OneSec      EQU     23              ; 1 second delay (at 23Hz)
TwoSec      EQU     46              ; 2 second delay (at 23Hz)
LCD_DAT     EQU     PORTB           ; LCD data port, bits - PB7,...,PB0
LCD_CNTR    EQU     PTJ             ; LCD control port, bits - PJ7(E),PJ6(RS)
LCD_E       EQU     $80             ; LCD E-signal pin
LCD_RS      EQU     $40             ; LCD RS-signal pin

;*****************************************************************
;* Variable/Data Section                                        *
;*****************************************************************
            ORG     $3850           ; Where our TOF counter register lives

TOF_COUNTER RMB     1               ; The timer, incremented at 23Hz
AT_DEMO     RMB     1               ; The alarm time for this demo

;*****************************************************************
;* Code Section                                                 *
;*****************************************************************
            ORG     $4000           ; Where the code starts

Entry:
_Startup:
            LDS     #$4000          ; Initialize the stack pointer
            JSR     initLCD         ; Initialize the LCD
            JSR     clrLCD          ; Clear LCD & home cursor
            JSR     ENABLE_TOF      ; Jump to TOF initialization
            CLI                     ; Enable global interrupt
            
            LDAA    #'A'            ; Display A (for 1 sec)
            JSR     putcLCD         ; --"--
            
            LDAA    TOF_COUNTER     ; Initialize the alarm time
            ADDA    #OneSec         ; by adding on the 1 sec delay
            STAA    AT_DEMO         ; and save it in the alarm

CHK_DELAY_1:
            LDAA    TOF_COUNTER     ; If the current time
            CMPA    AT_DEMO         ; equals the alarm time
            BEQ     A1              ; then display B
            BRA     CHK_DELAY_1     ; and check the alarm again

A1:
            LDAA    #'B'            ; Display B (for 2 sec)
            JSR     putcLCD         ; --"--
            
            LDAA    AT_DEMO         ; Initialize the alarm time
            ADDA    #TwoSec         ; by adding on the 2 sec delay
            STAA    AT_DEMO         ; and save it in the alarm

CHK_DELAY_2:
            LDAA    TOF_COUNTER     ; If the current time
            CMPA    AT_DEMO         ; equals the alarm time
            BEQ     A2              ; then display C
            BRA     CHK_DELAY_2     ; and check the alarm again

A2:
            LDAA    #'C'            ; Display C (forever)
            JSR     putcLCD         ; --"--
            SWI

;*****************************************************************
;* Subroutine Section                                           *
;*****************************************************************

; Initialize LCD
initLCD:
            BSET    DDRB,%11111111        ; Configure pins PS7, PS6, PS5, PS4 for output (LCD data lines)
            BSET    DDRJ,%11000000        ; Configure pins PE7 (RS) and PE4 (E) for output
            LDY     #2000                 ; Wait for LCD to be ready, set 2000 for ideal place
            JSR     del_50us              ; Delay ~2000 × 50 µs = 0.1 s total
                                                                                       
            LDAA    #$28                  ; Set 4-bit data mode, 2-line display, 5x8 font  ()
            JSR     cmd2LCD

            LDAA    #$0C                  ; Display ON, cursor OFF, blinking OFF
            JSR     cmd2LCD

            LDAA    #$06                  ; Move cursor right after entering a character
            JSR     cmd2LCD
            
            RTS

; Clear LCD
clrLCD:
            LDAA  #$01            ; clear cursor and return to home position
            JSR   cmd2LCD         ; -"-
            LDY   #40             ; wait until "clear cursor" command is complete
            JSR   del_50us        ; -"-
            RTS

; 50 microsecond delay
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

; Send command to LCD
cmd2LCD:    BCLR  LCD_CNTR,LCD_RS ; select the LCD Instruction Register (IR)
            JSR   dataMov         ; send data to IR
            RTS


putcLCD     BSET  LCD_CNTR,LCD_RS ; select the LCD Data register (DR)
            JSR   dataMov         ; send data to DR
            RTS

; Move data to LCD
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

; Enable Timer Overflow
ENABLE_TOF:
            MOVB    #0, TOF_COUNTER ; Initialize counter to 0 so no random delay times
            LDAA    #%10000000      ; Enable TCNT timer
            STAA    TSCR1           ; Store to Timer System Control Register 1
            LDAA    #%10000000      ; Prepare to clear TOF flag
            STAA    TFLG2           ; Clear Timer Overflow Flag
            
            LDAA    #%10000100      ; Enable TOI interrupt + prescale factor = 16
            STAA    TSCR2           ; Store to Timer System Control Register 2
            RTS     ;return via rti

; Timer Overflow Interrupt Service Routine
TOF_ISR:
            INC     TOF_COUNTER     ; Increment timer counter
            LDAA    #%10000000      ; Prepare to clear TOF flag
            STAA    TFLG2           ; Clear Timer Overflow Flag
            RTI

;*****************************************************************
;* Interrupt Vectors                                            *
;*****************************************************************
            ORG     $FFFE
            DC.W    Entry           ; Reset Vector

