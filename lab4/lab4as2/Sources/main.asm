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

;*****************************************************************
;* 5 Second Delay Section                                       *
;*****************************************************************

DT_DEMO     EQU     115             ; 5 second delay (115 TOF interrupts ˜ 5 seconds)

;*****************************************************************
;* Variable/Data Section                                        *
;*****************************************************************
;only put necessary definitions
            ORG     $3850

TOF_COUNTER RMB     1
AT_DEMO     RMB     1

;*****************************************************************
;* Code Section                                                 *
;*****************************************************************
            ORG     $4000

Entry:
_Startup:   ;from START in figure 2
            LDS     #$4000          ; Initialize stack pointer
            JSR     ENABLE_TOF      ; Jump to TOF initialization
            CLI                     ; Enable interrupts
            
             
            LDAA    TOF_COUNTER     ; Get current timer value
            ADDA    #DT_DEMO        ; Add 5 second delay, (115)
            STAA    AT_DEMO         ; Save alarm time

CHK_DELAY:
            LDAA    TOF_COUNTER     ; Read current timer value
            CMPA    AT_DEMO         ; Compare with alarm time
            BEQ     STOP_HERE       ; If equal, stop
            NOP                     ; Do something during delay
            BRA     CHK_DELAY       ; Continue checking
;delay so code doesn't just end instantly

            ;figure 2
STOP_HERE:
            SWI                     ; Stop program
            BRA     STOP_HERE       ; Infinite loop after SWI

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
            RTS     ;return via rti

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

;*****************************************************************
;* Interrupt Vectors                                            *
;*****************************************************************
            ORG     $FFFE
            FDB     Entry           ; Reset Vector
            
            ORG     $FFDE           ;more efficiency, is it supposed to be FFCE?
            FDB     TOF_ISR         ; Timer Overflow Interrupt Vector
