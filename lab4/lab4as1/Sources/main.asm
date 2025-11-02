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

; variable/data section

 ifdef _HCS12_SERIALMON
            ORG $3FFF - (RAMEnd - RAMStart)
 else
            ORG RAMStart
 endif

; code section
            ORG   $4000
Entry:
_Startup:
            LDS   #RAMEnd+1       ; initialize stack pointer
            CLI                   ; enable interrupts
            
;************************************************************
;* Motor Control Section                                    *
;************************************************************
mainLoop:
            BSET    DDRA,%00000011
            BSET    DDRT,%00110000
            JSR     STARFWD
            JSR     PORTFWD
            JSR     STARON
            JSR     PORTON
            JSR     STARREV
            JSR     PORTREV
            JSR     STAROFF
            JSR     PORTOFF
            BRA     *
            
;star board
STARON:
            LDAA    PTT
            ORAA    #%00100000 ;port 5
            STAA    PTT
            RTS

STAROFF:
            LDAA    PTT
            ANDA    #%11011111  ;if 0 for 5,off ;
            STAA    PTT
            RTS
STARFWD:
            LDAA    PORTA
            ANDA    #%11111101 ;port 5, 0 for forward 
            STAA    PORTA
            RTS

STARREV:
            LDAA    PORTA
            ORAA    #%00000010  ;port 5, 1 for on
            STAA    PORTA
            RTS
                         
;port
PORTFWD:
            LDAA    PORTA  ;located at address $0000 
            ANDA    #%11111110   ;clears bit 0 
            STAA    PORTA
            RTS

PORTREV:
            LDAA    PORTA
            ORAA    #%00000001  ;port0
            STAA    PORTA
            RTS
PORTON:
            LDAA    PTT
            ORAA    #%00010000 ;port 5, 1 for on
            STAA    PTT
            RTS

PORTOFF:
            LDAA    PTT
            ANDA    #%11101111  ; port 5, 0 for off
            STAA    PTT
            RTS          
            
;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector
