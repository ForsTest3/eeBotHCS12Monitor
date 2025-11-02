;*****************************************************************
;*                                                               *
;*  Program:    Unsigned Multiplication                          *
;*  Purpose:    Multiplies two 8-bit numbers to give 16-bit      *
;*  Processor:  HCS12                                            *
;*  Author:     [Daniel]                                         *
;*                                                               *
;*  Description:                                                 *
;*  This program demonstrates unsigned multiplication of         *
;*  two 8-bit numbers stored in memory. The 16-bit result        *
;*  is stored in a separate memory location.                     *
;*                                                               *
;*****************************************************************

; Export symbols
            XDEF    Entry, _Startup
            ABSENTRY Entry

; Include derivative-specific definitions
            INCLUDE 'derivative.inc'

; =============================================================
; Data section
; =============================================================
                ORG   $3000
MULTIPLICAND    FCB  $05  ; First Number (Hex format often preferred)
MULTIPLIER      FCB  $06  ; Second number
PRODUCT         RMB  2    ; 16-bit product

; =============================================================
; Code section
; =============================================================
            ORG   $4000

DELAY    LDX   #$FFFF      ; Load X with maximum 16-bit value (65535)
DELAY_LOOP
         DEX               ; Decrement X (X = X - 1)
         BNE   DELAY_LOOP  ; Branch if X != 0
         RTS               ; Return from subroutine
            
Entry:
_Startup:
            LDAA    MULTIPLICAND     ; Load multiplicand into A
            LDAB    MULTIPLIER       ; Load multiplier into B
            MUL                          ; D = A * B
            STD     PRODUCT          ; Store 16-bit result
            RTS                      ; Return

;**************************************************************
;*                 Interrupt Vectors                          *
;**************************************************************
            ORG     $FFFE
            DC.W    Entry             ; Reset Vector
