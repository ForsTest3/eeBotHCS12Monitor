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

ROMStart    EQU  $4000  ; absolute address to place my code/constant data

; variable/data section
            ORG RAMStart
; Insert here your data definition.
Counter     DS.W 1
FiboRes     DS.W 1

; code section
            ORG   ROMStart

Entry:
_Startup:
            LDS   #RAMEnd+1       ; initialize the stack pointer

            ; I/O Port initialization for keypad and LED
            BSET  DDRP, %11111111 ; Configure Port P for output (LED2 control)
            BSET  DDRE, %00010000 ; Configure pin PE4 for output (enable bit)
            BCLR  PORTE, %00010000 ; Enable keypad

            CLI                   ; enable interrupts

mainLoop:
            ; Read keypad and display on LED
            LDAA  PTS             ; Read a key code into AccA
            LSRA                  ; Shift right AccA
            LSRA                  ; -"-
            LSRA                  ; -"-
            LSRA                  ; -"-
            STAA  PTP             ; Output AccA content to LED2

            ; Fibonacci calculation
            LDX   #1              ; X contains counter
counterLoop:
            STX   Counter         ; update global.
            BSR   CalcFibo
            STD   FiboRes         ; store result
            LDX   Counter
            INX
            CPX   #24             ; larger values cause overflow.
            BNE   counterLoop
            BRA   mainLoop        ; restart.

CalcFibo:  ; Function to calculate fibonacci numbers. Argument is in X.
            LDY   #$00            ; second last
            LDD   #$01            ; last
            DBEQ  X,FiboDone      ; loop once more (if X was 1, were done already)
FiboLoop:
            LEAY  D,Y             ; overwrite second last with new value
            EXG   D,Y             ; exchange them -> order is correct again
            DBNE  X,FiboLoop
FiboDone:
            RTS                   ; result in D

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG   $FFFE
            DC.W  Entry           ; Reset Vector
