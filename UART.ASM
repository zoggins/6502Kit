; BOOT LOADER for 6502 TRAINER KIT
; WRITTEN BY WICHIT SIRICHOTE
; DECEMBER 24, 2014
; TASM ASSEMBLER


GPIO1   .EQU 8000H
PORT0   .EQU 8001H
PORT1   .EQU 8002H
PORT2   .EQU 8003H


 	  ; page zero register definition

       
REG_E   .EQU 80H
REG_D   .EQU 81H
REG_B   .EQU 82H
REG_C   .EQU 83H
HL      .EQU 84H           ; 84H = L 85H = H
DE      .EQU 86H
REG_A   .EQU 88H

_ERROR  .EQU 89H           ; ERROR FLAG FOR INTEL HEX FILE DOWNLOADING
BCC     .EQU 8AH           ; BYTE CHECK SUM



;	.ORG 0C000H

	.ORG 4000H         ; FOR TESTING IN RAM

	LDX #0FFH
	TXS
	CLI
	LDA #0
	STA HL
	LDA #0C0H
	STA HL+1 

	JMP MAIN

BIT_DELAY LDY #76      ; 1190 Hz TEST AT 1MHZ OSCILLATOR
LOOP      DEY
          BNE LOOP
	  RTS

BIT1_5_DELAY LDY #114      ; DELAY 1.5 BIT
LOOP1      DEY
          BNE LOOP1
	  RTS



; SEND ASCII LETTER TO TERMINAL
; ENTRY: A

SEND_BYTE: STA REG_E  ; SAVE ACCUMULATOR
             
          LDA #7FH
	  STA PORT1
          JSR BIT_DELAY    ; SEND START BIT
	  
          LDA #8
	  STA REG_D
                   
CHK_BIT:   LDA REG_E
           AND #1
	   BEQ SEND_ZERO
          
	   LDA #0FFH
	   STA PORT1

           JMP NEXT_BIT
	  
             
SEND_ZERO: LDA #7FH
           STA PORT1
	   JMP NEXT_BIT
            
NEXT_BIT:  JSR BIT_DELAY
     
           LSR REG_E
	   DEC REG_D
           BNE CHK_BIT
          
           LDA #0FFH
	   STA PORT1
	   JSR BIT_DELAY
	   RTS


; RECEIVE BYTE FROM 2400 BIT/S TERMINAL
; EXIT: A

CIN	 LDA PORT0 
         AND #80H
	 BNE CIN
         
	 JSR BIT1_5_DELAY
	 
	 LDA #7
	 STA REG_D
	 LDA #0
	 STA REG_E

    
            
CHK_BIT_RX   LDA PORT0
           AND #80H
           BNE BIT_IS_ONE
           
           LDA REG_E
	   AND #7FH
	   STA REG_E
	   JMP NEXT_BIT_RX
             
BIT_IS_ONE LDA REG_E
           ORA #80H
	   STA REG_E
           JMP NEXT_BIT_RX
            
NEXT_BIT_RX  JSR BIT_DELAY
     
           LSR REG_E

           DEC REG_D
	   BNE CHK_BIT_RX

	   JSR BIT_DELAY    ; CENTER OF STOP BIT
           
	   LDA REG_E 

	   RTS


; PRINT TEXT FROM STRING AREA
; ENTRY: X POINTED TO OFFSET

PSTRING   LDA TEXT1,X
          CMP #0
	  BNE PRINT_IT
	  RTS

PRINT_IT  JSR SEND_BYTE
          INX
	  JMP PSTRING

CR        .EQU 0DH
LF        .EQU 0AH
EOS       .EQU 0 

;NEW LINE
; PRINT CR, LF

NEW_LINE     LDA #0DH
	     JSR SEND_BYTE
	     LDA #0AH
	     JSR SEND_BYTE
	     RTS


; WRITE NIBBLE TO TERMINAL
OUT1X        AND #0FH  
             CLC
	     ADC #30H 
             CMP  #3AH
	     BCC OUT1X1
	     CLC
	     ADC #7
OUT1X1	     JSR SEND_BYTE
	     RTS


OUT2X        PHA
             
	     LSR A
             LSR A
	     LSR A
	     LSR A
	     
	   ;  STA GPIO1

	     JSR OUT1X
	     PLA
	     JSR OUT1X
	     RTS


; INCREMENT HL
; INCREMENT 16-BIT POINTER FOR 16-BIT MEMORY ACCESS

INC_HL       CLC
             LDA HL
	     ADC #1
	     STA HL
	     LDA HL+1
	     ADC #0
	     STA HL+1
	     RTS


; PRINT LINE OF MEMORY POINTED TO HL

PRINT_LINE   JSR NEW_LINE
             LDA #16
             STA REG_C

	     
	     
             LDA HL+1
	     JSR OUT2X
	     LDA HL
	     JSR OUT2X

	     LDA #':'
	     JSR SEND_BYTE

PRINT_LINE2  LDY #0
             LDA (HL),Y
	     
	     JSR OUT2X
	      
	     LDA #' '
	     JSR SEND_BYTE
	     
	     JSR INC_HL
	     
	     DEC REG_C
	    
	     BNE PRINT_LINE2

	     RTS

; CONVERT ASCII TO HEX
; ENTRY: A

TO_HEX     SEC
           SBC #30H
	   CMP #10H
	   BCC ZERO_NINE
	   AND #11011111B
	   SEC
	   SBC #7

ZERO_NINE  RTS

; CONVERT TWO ASCII LETTERS  TO SINGLE BYTE
; EXIT: A

GET_HEX    JSR CIN       
	   JSR TO_HEX
           ASL A
	   ASL A
	   ASL A
	   ASL A

	   STA GPIO1
	   
	   STA REG_A
	   
	   JSR CIN
	   JSR TO_HEX
	   CLC
	   ADC REG_A

	   RTS

; CONVERT TWO ASCII LETTERS  TO SINGLE BYTE
; EXIT: A

GET_HEX2    JSR CIN     
           PHA
	   JSR SEND_BYTE   ; ECHO TO TERMINAL
	   PLA
	   JSR TO_HEX
           ASL A
	   ASL A
	   ASL A
	   ASL A

	   STA GPIO1
	   
	   STA REG_A
	   
	   JSR CIN
	   PHA
	   JSR SEND_BYTE
	   PLA
	   JSR TO_HEX
	   CLC
	   ADC REG_A

	   RTS

;-----------------------------------------------------
SET_NEW_ADDRESS

          JSR SEND_BYTE
	  LDX #PROMPT&00FFH
          JSR PSTRING
	  JSR GET_HEX2
	  STA HL+1
	  JSR GET_HEX2
	  STA HL
	  RTS

ADD_BCC   CLC
          ADC BCC
	  STA BCC
	  RTS

;---------------------------------------------------------
; GET_RECORD READS INTEL HEX FILE AND SAVE TO MEMORY

GET_RECORD LDA #0
	   STA _ERROR

GET_RECORD1 JSR CIN
	   CMP #':'
	   BNE GET_RECORD1
	   
	   
	   LDA #0	
	   STA BCC
	 
	   JSR GET_HEX
	   STA REG_C     ; GET NUMBER OF BYTE
	   
	   JSR ADD_BCC

	   JSR GET_HEX
           STA HL+1
	   
	   JSR ADD_BCC

	   JSR GET_HEX
	   STA HL        ; GET LOAD ADDRESS

	   JSR ADD_BCC

	   JSR GET_HEX

	   CMP #0

	   BEQ DATA_RECORD
	   
WAIT_CR	   JSR CIN
	   CMP #0DH
	   BNE WAIT_CR
	   
	   STA GPIO1
	   
	   LDA _ERROR
	   CMP #1
	   BNE NOERROR
	   
	   STA GPIO1

NOERROR    RTS

DATA_RECORD

	   JSR GET_HEX
	   LDY #0
	   STA (HL),Y	; WRITE TO MEMORY
	   
	   JSR ADD_BCC

	   STA GPIO1
	   
	   JSR INC_HL
	   
	   DEC REG_C
	   BNE DATA_RECORD ; UNTIL C=0

           LDA BCC
	   EOR #0FFH    ; ONE'S COMPLEMENT
	   CLC          
	   ADC #1       ; TWO'S COMPLEMENT
	   STA BCC
	   
	   
	   JSR GET_HEX	   ; GET BYTE CHECK SUM
	   
	   CMP BCC	; COMPARE WITH BYTE CHECK SUM
	   BEQ SKIP11
	  
	   LDA #1
	   STA _ERROR    ; ERROR FLAG =1
	   
	   
SKIP11
	   
	   JMP GET_RECORD1     ; NEXT LINE 



SEND_PROMPT

          JSR NEW_LINE
           LDA HL+1
	   JSR OUT2X
	   LDA HL
	   JSR OUT2X

         
	  LDX #PROMPT&00FFH
          JSR PSTRING
          RTS

;---------------------------------------------------------

MAIN      JSR CIN
          STA GPIO1 
          CMP #CR
	  BNE CHECK_COMMAND_P
	  
	  JSR NEW_LINE
	  LDX #0
	  JSR PSTRING

          JSR SEND_PROMPT
	  
	  JMP MAIN

CHECK_COMMAND_P

          CMP #'P'
	  BNE CHECK_COMMAND_N

       	  JSR PRINT_LINE

	  JMP MAIN

CHECK_COMMAND_N

          CMP #'N'
	  BNE CHECK_COMMAND_L

          JSR SET_NEW_ADDRESS
	 
	  JMP MAIN

CHECK_COMMAND_L

          CMP #'L'
	  BNE COMMAND_GO

	  JSR SEND_BYTE

	  JSR GET_RECORD

	  JMP MAIN

COMMAND_GO
          CMP #'G'
	  BNE MAIN
	  JMP (0084H)


	;  .FILL 3000h, 0FFH

; PAGE FOR CONSTANT STRINGS AREA

	  ;.ORG 0EF00H        ; ROM MONITOR
           .ORG 06F00H        ; RAM TEST 


;TEXT1      .TEXT "6502 TRAINER KIT V1.0 ROM"
 ;          .BYTE 0
TEXT1      .TEXT "6502 TRAINER KIT V1.0 RAM"
	   .BYTE 0

PROMPT     .TEXT ">>"
           .BYTE 0




	  ; RESET VECTOR


	  .ORG 0FFFCH

	  .BYTE 00,0C0H




	  .END

