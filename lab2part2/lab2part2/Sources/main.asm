; export symbols
            XDEF Entry, _Startup            ; export 'Entry' symbol
            ABSENTRY Entry        ; for absolute assembly: mark this as application entry point

; Include derivative-specific definitions 
		INCLUDE 'derivative.inc' 

;*****************************************************************
;* Writing to the LCD                                            *
;*****************************************************************

; Definitions
LCD_DAT     EQU   PTS        ; LCD data port S, pins PS7, PS6, PS5, PS4
LCD_CNTR    EQU   PORTE      ; LCD control port E, pins PE7 (RS), PE4 (E)
LCD_E       EQU   $10        ; LCD enable signal, pin PE4
LCD_RS      EQU   $80        ; LCD register select signal, pin PE7

; Data section
            ORG   $3000      ; place variables in RAM
Num1        FCB   $12        ; test value 1                $3000
Num2        FCB   $34        ; test value 2                $3001
mem1        RMB   1          ; storage for ASCII characters 
mem2        RMB   1                                     ;  $3003...
mem3        RMB   1
mem4        RMB   1
mem5        RMB   1

; Code section
            ORG   $4000

msg1        dc.b  "Test Message. ",0   ;message
                                   
Entry:
_Startup:
            LDS   #$4000     ; initialize stack pointer
            JSR   initLCD    ; initialize LCD
            

;*****************************************************************
;* Program starts here                                           *
;*****************************************************************
MainLoop:
            JSR   clrLCD     ; clear LCD and home cursor
            LDX   #msg1      ; display msg1, loads address msg1 into ldx
            JSR   putsLCD    ; jumps to putsLCD

            ; left and right for both nums 4 and 4
            LDAA  Num1       ; load contents of Num1 into A
            JSR   leftHLF    ; convert left half of A into ASCII
            STAA  mem1       ; store ASCII byte into mem1

            LDAA  Num1       ; load contents of Num1 into A
            JSR   rightHLF   ; convert right half of A into ASCII
            STAA  mem2       ; store ASCII byte into mem2

            LDAA  Num2       ; load contents of Num2 into A
            JSR   leftHLF    ; convert left half of A into ASCII
            STAA  mem3       ; store ASCII byte into mem3

            LDAA  Num2       ; load contents of Num2 into A
            JSR   rightHLF   ; convert right half of A into ASCII
            STAA  mem4       ; store ASCII byte into mem4


            ;
            LDAA  #0         ; load 0 into A, 
            STAA  mem5       ; store string termination character 00 (store from a to mem5)

            LDX   #mem1      ; output 4 ASCII characters
            JSR   putsLCD    ; -"-

            LDY   #20000     ; delay 1s (20000 × 50us = 1s)
            JSR   del_50us
            BRA   MainLoop   ; loop

;*****************************************************************
;* subroutine section                                            *
;*****************************************************************

;*****************************************************************
;* init of LCD: 4-bit data width, 2 line display, turn on display,
;* cursor and blinking off. shift cursor right.
;*****************************************************************
initLCD:
            BSET  DDRS, %11110000   ; configure pins PS7, PS6, PS5, PS4 for output
            BSET  DDRE, %10010000   ; configure pins PE7, PE4 for output
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
       
eloop:      LDX   #30               ; 2 E-clk     load 30 into register X
iloop:      PSHA                    ; 2 E-clk    starting here inclusive
            PULA                    ; 3 E-clk 5
            PSHA                    ; 2 E-clk      push register A
            PULA                    ; 3 E-clk  10  pull register A
            PSHA                    ; 2 E-clk      pushing and pulling register A value doesnt change
            PULA                    ; 3 E-clk  15  this is purely time convention
            PSHA                    ; 2 E-clk
            PULA                    ; 3 E-clk  20
            PSHA                    ; 2 E-clk
            PULA                    ; 3 E-clk  25
            PSHA                    ; 2 E-clk
            PULA                    ; 3 E-clk  30
            PSHA                    ; 2 E-clk
            PULA                    ; 3 E-clk  35 
            NOP                     ; 1 E-clk       no operation, doesnt change any values, burn cycle
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

;*****************************************************************
;* binary to ASCII conversion routines                           *
;*****************************************************************
leftHLF:
            LSRA                     ; shift data right 4 times
            LSRA
            LSRA                      ;01101111 -> 00110111s
            LSRA                     ;isolate for both numbers separate, the higher bits (left side)
            ;will be all 0 for ANDA 
rightHLF:
            ANDA  #$0F               ; mask top half, AND register A with $0F (15=00001111)
            ADDA  #$30               ; convert to ASCII, adds 30 (ascii number range)
            CMPA  #$39               ;compare if = 39, if less than then goes to BLE out execution and skips ADDA
            BLE   out                ; jump if 0-9, otherwise skips BLE out and goes to ADDA, 40 and past is punctuation
            ADDA  #$07               ; convert to hex A-F
out:        RTS

;*****************************************************************
;*                 Interrupt Vectors                             *
;*****************************************************************
            ORG   $FFFE
            DC.W  Entry              ; Reset Vector