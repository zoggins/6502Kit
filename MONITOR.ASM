;----------------------------------------------------------------------------
; Monitor program source code for 6502 Microprocessor Kit
; Written by Wichit Sirichote, kswichit@kmitl.ac.th
; Copyright (c) 2015
; 
; Source code was assembled with tasm assembler
; Example of using tasm
;
; d:\tasm\tasm -65 monitor.asm
;
; The object file will be Intel hex file ready for EPROM programmer
; The physical location is the 2nd block of 64kB space.
; To program the 32kB EPROM, we must move it to the 1st block.
; 
;
;
; 26 DECEMBER 2014
; 27 DECEMBER 2014
;   -ADD OUT OF RANGE CHECK FOR RELATIVE BYTE CALCULATION              
;   -ADD DOWNLOAD HEX FILE TO MONITOR SOURCE
; 29 DECEMBER 2014
;   -ADD START MESSAGE ON COLD BOOT
; 30 DECEMBER 2014
;   -TEST SINGLE STEP WITH 74LS164
;   - ADD REPEAT KEY
;   - LOWER REPEAT SPEED
;   - REMOVE ACCUMALATOR DISPLAY ON BREAK
;  2 JANUARY 2015
;  - REMOVE BINARY DISPLAY IN REGISTER MODE
;  - ADD REGISTER MODE DISPLAY FOR 10 BYTES ZERO PAGE, $00 TO $09
;  3 JANUARY 2015
;  - PROVIDE PROGRAM COUNTER SAVING FOR SINGLE STEP RUNNING
;    now user may change display address, data, to get back current address being executed,
;    press PC key to restore it, then press step
;
;  27 February 2015
; lower brightness of the 7-segment
; calibrate beep frequency to 523Hz
; 2 March 2015
; add hex file download using MOS hex format
; now the board can accept both Intel and MOS hex file format. Tested with TASM assembler
; no error, the GPIO1 will display 0D (CR), if error it will show 01.
;
; 21 March fix cold boot message, make beep on cold boot  




; address of the I/O ports

GPIO1   .EQU 8000H
PORT0   .EQU 8001H
PORT1   .EQU 8002H
PORT2   .EQU 8003H

DIGIT   .EQU 8002H
SEG7    .EQU 8003H
KIN     .EQU 8001H
 

    

 ; page zero register definition
 ; LOCATION $00 TO $7F ARE 128 BYTES FOR USER PROGRAM TESTING 
         
	 .DSEG
	 .ORG 80H

; zero page memory definitions for monitor use       
REG_E   .BLOCK 1
REG_D   .BLOCK 1
REG_B   .BLOCK 1
REG_C   .BLOCK 1
HL      .BLOCK 2           ; 84H = L 85H = H
DE      .BLOCK 2
REG_A   .BLOCK 1

_ERROR  .BLOCK 1           ; ERROR FLAG FOR INTEL HEX FILE DOWNLOADING
BCC     .BLOCK 2           ; BYTE CHECK SUM
BUFFER  .BLOCK 6          ; 8BH - 90H PAGE ZERO DISPLAY BUFFER
INVALID .BLOCK 1          ; INVALID KEY HAS BEEN PRESSED FLAG BIT
                          ; 0 VALID
			  ; 1 INVALID

KEY     .BLOCK 1
STATE   .BLOCK 1
ZERO_FLAG .BLOCK 1          ; ZERO WHEN HEX KEY PRESSED FOR ADDRESS OR DATA KEY

DISPLAY .BLOCK 2         ; display address 

PC_USER  .BLOCK 2       ; FOR SAVING CURRENT PC, ON RESET, IT SETS TO 200H 
USER_A  .BLOCK 1
USER_X  .BLOCK 1
USER_Y  .BLOCK 1
USER_S  .BLOCK 1         ; USER STACK POINTER
USER_P  .BLOCK 1         ; PROGRAM STATUS REGISTER
SAVE_SP .BLOCK 1         ; SAVE SYSTEM STACK 

START_ADDRESS .BLOCK 2
DESTINATION  .BLOCK 2    ; FOR OFFSET BYTE CALCULATION  
OFFSET_BYTE .BLOCK 2     ; OFFSET BYTE = DESTINATION - START_ADDRESS
COLD    .BLOCK 1         ; COLD BOOT OR WARM BOOT 

REPDELAY .BLOCK 1
SAVE_X   .BLOCK 1
SAVE_Y   .BLOCK 1

DEBUG    .BLOCK 2      ; FOR PROGRAM DEBUGGING


 
          .CSEG 

          .ORG 0C000H    ; START ADDRESS FOR ROM
        ;  .ORG 1000H     ; START ADDRESS FOR CODE TESTING IN RAM

                LDA #$BF ; turn off break signal
		STA PORT1
		LDA #0
		STA PORT2 ; turn of 7-segment
	
	; power up delay

		LDX #0
POWER_UP_DELAY	DEX 
	        BNE POWER_UP_DELAY

         ; jump to main code

	        JMP MAIN

;----------------------- 2400 BIT/S SOFTWARE UART ---------------------------------
; one bit delay for 2400 bit/s UART

BIT_DELAY LDY #76      ; 1190 Hz TEST AT 1MHZ OSCILLATOR
LOOP      DEY
          BNE LOOP
	  RTS

; 1.5 bit delay

BIT1_5_DELAY LDY #114      ; DELAY 1.5 BIT
LOOP1      DEY
          BNE LOOP1
	  RTS

; SEND ASCII LETTER TO TERMINAL
; ENTRY: A

SEND_BYTE: STA REG_E  ; SAVE ACCUMULATOR
             
          LDA #3FH    ; start bit is zero
	  STA PORT1
          JSR BIT_DELAY    ; delay one bit
	  
          LDA #8      ; 8-data bit wil be sent
	  STA REG_D
                   
CHK_BIT:   LDA REG_E
           AND #1
	   BEQ SEND_ZERO
          
	   LDA #0BFH
	   STA PORT1

           JMP NEXT_BIT
	  
             
SEND_ZERO: LDA #3FH
           STA PORT1
	   JMP NEXT_BIT
            
NEXT_BIT:  JSR BIT_DELAY
     
           LSR REG_E
	   DEC REG_D
           BNE CHK_BIT
          
           LDA #0BFH
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
	   BEQ GET_RECORD2
	   
	   CMP #$3B          ; ';'
	   BNE GET_RECORD1

	   JMP GET_MOS2
	   
	   
GET_RECORD2

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

; SHOW ERROR ON LED
	;  JSR OUT_OFF_RANGE
	   
	   STA GPIO1

NOERROR   
           RTS

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

;===================================================================
; get MOS record
; sample MOS record
;
;18 0200 A9018500182600A5008D0080A200A00088D0FDCAD0F84C05 09B3
;01 0218 02 001D
;00
;
; 18 is number of byte
; 0200 is load address
; A9, 01, 85.. data byte
; 09B3 is 16-bit check sum



GET_MOS1
           JSR CIN
	   CMP #$3B         ; ';'
	   BNE GET_MOS1

GET_MOS2

	   LDA #0	
	   STA BCC
	   STA BCC+1  ; MOS uses 16-bit checksum

	 
	   JSR GET_HEX
	   STA REG_C     ; GET NUMBER OF BYTE

	   CMP #0
	   BEQ END_RECORD
	   
	   JSR ADD_BCC_MOS

	   JSR GET_HEX
           STA HL+1
	   
	   JSR ADD_BCC_MOS

	   JSR GET_HEX
	   STA HL        ; GET LOAD ADDRESS

	   JSR ADD_BCC_MOS

	   JMP DATA_RECORD2
	   	   
END_RECORD JSR CIN
	   CMP #0DH
	   BNE END_RECORD
	   
	   STA GPIO1
	   
	   LDA _ERROR
	   CMP #1
	   BNE NOERROR2

; SHOW ERROR ON LED
	   
	   STA GPIO1
	   

NOERROR2   
           RTS

DATA_RECORD2

	   JSR GET_HEX
	   LDY #0
	   STA (HL),Y	; WRITE TO MEMORY
	   
	   JSR ADD_BCC_MOS

	   STA GPIO1
	   
	   JSR INC_HL
	   
	   DEC REG_C
	   BNE DATA_RECORD2 ; UNTIL C=0

; now get 16-bit check sum          
	   
	   JSR GET_HEX	   ; GET 16-bit CHECK SUM
	   STA HL+1
	;   STA DEBUG+1

	   JSR GET_HEX
	   STA HL          ; check sum now stored in HL+1 and HL
         ;  STA DEBUG

	   LDA BCC+1
	   CMP HL+1
	   BNE error_mos
	   LDA BCC
	   CMP HL
	   BNE error_mos
	   
	   JMP SKIP12

error_mos
	   LDA #1
	   STA _ERROR    ; ERROR FLAG =1
	   
	   
SKIP12
	   
	   JMP GET_MOS1     ; NEXT LINE 


; add 16-bit check sum, stores in BCC+1 and BCC

ADD_BCC_MOS

          CLC
          ADC BCC
	  STA BCC
	  LDA #0
	  ADC BCC+1
	  STA BCC+1
	  RTS


;--------------------------------- END UART CODE ------------------------------------

; SCAN DISPLAY ONLY
; ENTRY: X POINTED TO NEXT MESSAGE BYTE
;        FIX_MESSAGE LOCATION

SCAN2:
	STX REG_C
	LDA #1
	STA REG_E
	
	LDA #6
	STA HL
				
;to the active column.
KCOL2   LDA REG_E	

       	EOR #0FFH               ; COMPLEMENT IT
	
	AND #0BFH               ; BREAK MUST BE LOGIC '0' TO DISABLE
	STA DIGIT

	LDA START_MSG,X
	STA SEG7

	LDY #$5
DELAY5	DEY
	BNE DELAY5

	LDA #0                 ; TURN LED OFF
	STA SEG7



	
	INX
	
	LDA REG_E
	ASL A
	STA REG_E
		
	DEC  HL
	BNE  KCOL2

	LDX REG_C 

	RTS


; SCAN DISPLAY AND KEYBOARD
; ENTRY: DISPLAY BUFFER IN PAGE 0
; EXIT: KEY = -1 NO KEY PRESSED
;       KEY >=0 KEY POSITION
; REGSITERS USED: X,A,Y

SCAN1:

	
	LDX #0
	
	LDA #0
	STA REG_C
	
	LDA #-1
	STA KEY
	
	LDA #1
	STA REG_E
	
	LDA #6
	STA HL
				
;to the active column.
KCOL    LDA REG_E	

       	EOR #0FFH               ; COMPLEMENT IT
	AND #0BFH               ; MUST BE LOW FOR BREAK

	STA DIGIT

	LDA BUFFER,X
	STA SEG7

	LDY #$30
DELAY3	DEY
	BNE DELAY3

	LDA #0                 ; TURN LED OFF
	STA SEG7

	LDY #50
DELAY10	DEY
	BNE DELAY10
	

	LDA #6
	STA REG_B
	
	LDA KIN
	
	STA  REG_D

	
KROW	LSR  REG_D		;Rotate D 1 bit right, bit 0
				;of D will be rotated into
	BCS NOKEY			;carry flag.
	
	LDA REG_C
	STA KEY

NOKEY	INC REG_C		;Increase current key-code by 1.
	
	DEC REG_B
	BNE KROW
	
	INX
	
	LDA REG_E
	ASL A
	STA REG_E
		
	
	DEC  HL
	BNE  KCOL
	RTS


DEBOUNCE LDY #200
DELAY4   DEY
	 BNE DELAY4
	 RTS

;--------------------------------------------------------------------

SCANKEY JSR SCAN1
        LDA KEY
	CMP #-1
	BEQ KEY_RELEASED

	LDA PORT0
	AND #40H
	BNE SCANKEY

; IF REPEAT KEY WAS PRESSED, SLOW DOWN IT
          LDA #20H
          STA REPDELAY

DISPLAY4  JSR SCAN1
	  DEC REPDELAY
	  BNE DISPLAY4


          LDX #0         ; THEN REPEAT KEY PRESS        
          STX INVALID    ; RESET INVALID FLAG 
KEY_RELEASED

	JSR DEBOUNCE

UNTIL_PRESS
	
	JSR SCAN1
        LDA KEY
	CMP #-1
	BEQ UNTIL_PRESS

	JSR DEBOUNCE

	JSR SCAN1

	LDA KEY
	TAX
	LDA KEYTAB,X    ; OPEN TABLE
		
	;STA GPIO1       ; TEST NOW A IS INTERNAL CODE 
	RTS


; CONVERT LOW NIBBLE IN ACCUMULATOR TO 7-SEGMENT PATTERN
; ENTRY: A
; EXIT: A

NIBBLE_7SEG 
            TAX
            LDA SEGTAB,X
	    RTS


; CONVERT BYTE TO 7-SEGMENT PATTERN
; ENTRY: A
; EXIT: DE

BYTE_7SEG   PHA
            AND #0FH
            JSR NIBBLE_7SEG
	    STA DE
	    PLA
            LSR A
	    LSR A
	    LSR A
	    LSR A
	    JSR NIBBLE_7SEG
	    STA DE+1
	    RTS

; CONVERT BYTE TO 7-SEGMENT PATTERN AND SAVE TO DISPLAY BUFFER DATA FIELD
; ENTRY: A

DATA_DISPLAY PHA   ; SAVE ACCUMULATOR
             JSR BYTE_7SEG
	     LDA DE
	     STA BUFFER
	     LDA DE+1
	     STA BUFFER+1
             PLA
	     RTS

; CONVERT 16-BIT ADDRESS IN HL AND SAVE IT TO ADDRESS FILED DISPLAY BUFFER
; ENTRY: HL

ADDRESS_DISPLAY

            LDA HL
	    JSR BYTE_7SEG
	    LDA DE
	    STA BUFFER+2
	    LDA DE+1
	    STA BUFFER+3
	    LDA HL+1
	    JSR BYTE_7SEG
	    LDA DE
	    STA BUFFER+4
	    LDA DE+1
	    STA BUFFER+5
	    RTS

;**************************************************************************************88
;
; EXECUTE FUNCTIONS OR HEX KEY ENTERED 
; CHECK HEX KEY OR FUNCTIONS KEY
; ENTRY: A

KEYEXE     CMP #10H
	   BCS FUNCTION_KEY


;HHHHHHHHHHHHHHH   KEY HEX ENTERED HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH

           STA REG_C     ; SAVE HEX KEY
	   LDA STATE

	   CMP #1
	   BNE CHK_STATE2
	   
	   LDA REG_C
	   JMP HEX_ADDR

CHK_STATE2 CMP #2
           BNE CHK_STATE3
	   JMP HEX_DATA

CHK_STATE3 CMP #3
           BNE CHK_STATE5
	   JMP HEX_REG

CHK_STATE5 CMP #5
           BNE CHK_STATE6
	   JMP HEX_REL

CHK_STATE6 CMP #6
           BNE CHK_STATE7
	   JMP HEX_REL6

CHK_STATE7 CMP #7
           BNE CHK_STATE8
           JMP HEX_SEND_FILE

CHK_STATE8  CMP #8
            BNE CHK_STATE9
	    JMP HEX_SEND_FILE2

CHK_STATE9  lda REG_C
            sta GPIO1
            LDA #1         ; INVALID KEY PRESSED
	    STA INVALID
	    




; HEX KEY WAS PRESSED

           
	   RTS

;FFFFFFFFFFFFFFFFFFFFFF FUNCTION KEY FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

FUNCTION_KEY

          CMP #19H    ; KEY ADDR
	  BNE CHK_FUNC1
	  JMP KEY_ADDR

CHK_FUNC1 CMP #14H   ; KEY DATA
          BNE CHK_FUNC2
	  JMP KEY_DATA

CHK_FUNC2 CMP #10H   ; KEY +
          BNE CHK_FUNC3
	  JMP KEY_INC

CHK_FUNC3 CMP #11H    ; KEY -
          BNE CHK_FUNC4
	  JMP KEY_DEC

CHK_FUNC4  CMP #18H
           BNE CHK_FUNC5
	   JMP KEY_PC

CHK_FUNC5  CMP #1BH
           BNE CHK_FUNC6
	   JMP KEY_REG

CHK_FUNC6  CMP #12H
           BNE CHK_FUNC7
	   JMP KEY_GO

CHK_FUNC7  CMP #1DH
           BNE CHK_FUNC8
	   JMP KEY_REL

CHK_FUNC8  CMP #1FH
           BNE CHK_FUNC9
	   JMP KEY_DOWNLOAD_HEX

CHK_FUNC9 CMP #13H
          BNE CHK_FUNC10
	  JMP KEY_STEP
          
	  
CHK_FUNC10 CMP #16H
           BNE CHK_FUNC11
	   JMP KEY_INS

CHK_FUNC11 CMP #17H
           BNE CHK_FUNC12
	   JMP KEY_DEL
	   RTS

CHK_FUNC12 

          RTS

;----------------------------------------------------------------
NO_RESPONSE
           RTS


KEY_DEL    RTS

;------------------------------------------------------------------
; insert byte to current display+1
; shift down 1kB, 256 bytes.

KEY_INS   LDA STATE
          CMP #1
          BEQ KEY_INS1
	  CMP #2
	  BEQ KEY_INS1

	  JSR NO_RESPONSE
	  RTS

KEY_INS1  LDA DISPLAY
          STA DE
	  LDA DISPLAY+1
	  STA DE+1

	  CLC
          LDA DE+1
	  ADC #40   ; DE=DE+$400 
	  STA DE+1

	  

	  
	  RTS

	  





;--------------------------------------------------------------------
KEY_SEND_HEX
             LDA #7
	     STA STATE ; STATE = 7 FOR SENDING HEX FILE

             LDA #0
	     STA ZERO_FLAG
	     JSR STILL_ADDRESS
	     LDA #0AEH
	     STA BUFFER
	     LDA #2
	     STA BUFFER+1
	     RTS
              
	      RTS


;-------------------------------------------------------------
KEY_DOWNLOAD_HEX
              
	      LDA #0B3H    ; PRINT LOAD
	      STA BUFFER+5
	      LDA #85H
	      STA BUFFER+5
	      LDA #0A3H
	      STA BUFFER+4
	      LDA #3FH
	      STA BUFFER+3
	      LDA #0B3H
	      STA BUFFER+2
	      LDA #0
	      STA BUFFER+1
	      STA BUFFER

	     ; JSR NEW_LINE
	     ; JSR NEW_LINE
	     ; JSR NEW_LINE
              LDA #10
	      STA STATE
	      RTS

GO_STATE10    LDA #55H
	      STA GPIO1


	      JSR GET_RECORD  ; GET INTEL HEX FILE
	      
	      LDA #2
	      STA STATE
	      JSR STILL_DATA
	      
	      RTS


;-----------------------------------------------------------
KEY_REL      LDA #5
	     STA STATE ; STATE = 5 FOR RELATIVE BYTE CALCULATION

             LDA #0
	     STA ZERO_FLAG
	     JSR STILL_ADDRESS
	     LDA #0AEH
	     STA BUFFER
	     LDA #2
	     STA BUFFER+1
	     RTS
        

;---------------------------------------------------------
KEY_ADDR     LDA #1
             STA STATE     ; STATE =1 FOR ADDRESS MODE

	     LDA #0
	     STA ZERO_FLAG
	     
STILL_ADDRESS
             JSR READ_MEMORY
	     
	     LDA BUFFER+5
	     ORA #40H
	     STA BUFFER+5

	     LDA BUFFER+4
	     ORA #40H
	     STA BUFFER+4

	     LDA BUFFER+3
	     ORA #40H
	     STA BUFFER+3

             LDA BUFFER+2
	     ORA #40H
	     STA BUFFER+2

             LDA BUFFER+1
	     AND #~40H
	     STA BUFFER+1

	     LDA BUFFER
	     AND #~40H
	     STA BUFFER

             RTS
;---------------------------------------------------------
KEY_DATA     LDA #2
             STA STATE     ; STATE =2 FOR DATA MODE

	      LDA #0
	     STA ZERO_FLAG

STILL_DATA   JSR READ_MEMORY 

	     LDA BUFFER+5
	     AND #~40H
	     STA BUFFER+5

	     LDA BUFFER+4
	     AND #~40H
	     STA BUFFER+4

	     LDA BUFFER+3
	     AND #~40H
	     STA BUFFER+3

             LDA BUFFER+2
	     AND #~40H
	     STA BUFFER+2

             LDA BUFFER+1
	     ORA #40H
	     STA BUFFER+1

	     LDA BUFFER
	     ORA #40H
	     STA BUFFER

             RTS


; READ MEMORY

READ_MEMORY

        LDA DISPLAY
	STA HL
	LDA DISPLAY+1
	STA HL+1
	JSR ADDRESS_DISPLAY
        LDY #0
	LDA (HL),Y
	
	;STA GPIO1

	JSR DATA_DISPLAY
	RTS
;------------------------------------------------------------

HEX_SEND_FILE JSR HEX_ADDR
              LDA #0AEH
	      STA BUFFER
	      LDA #2
	      STA BUFFER+1
	      RTS

HEX_SEND_FILE2 JSR HEX_ADDR
              LDA #08FH
	      STA BUFFER
	      LDA #2
	      STA BUFFER+1
	      RTS

;------------------------------------------------------------

HEX_REL     JSR HEX_ADDR
            LDA #0AEH
	    STA BUFFER
	    LDA #2
	    STA BUFFER+1
	    RTS
            


HEX_REL6    JSR HEX_ADDR
            LDA #0B3H
	    STA BUFFER
	    LDA #2
	    STA BUFFER+1
	    RTS


;------------------- HEX KEY FOR ADDRESS -------------------

HEX_ADDR     LDA ZERO_FLAG
	     CMP #0
	     BNE SHIFT_ADDRESS

	     LDA #1
	     STA ZERO_FLAG   
             LDA #0
	     STA DISPLAY
	     STA DISPLAY+1

SHIFT_ADDRESS CLC
             ROL DISPLAY
	     ROL DISPLAY+1

             CLC
             ROL DISPLAY
	     ROL DISPLAY+1

	     CLC
             ROL DISPLAY
	     ROL DISPLAY+1

	     CLC
             ROL DISPLAY
	     ROL DISPLAY+1

	     LDA DISPLAY
	     ORA REG_C
	     STA DISPLAY

            ; JSR READ_MEMORY

	     JSR STILL_ADDRESS

	     RTS
;------------------------- HEX KEY FOR DATA MODE --------------------------


HEX_DATA     LDA ZERO_FLAG
	     CMP #0
	     BNE SHIFT_DATA

	     LDA #1
	     STA ZERO_FLAG   
             
	     LDA #0
	     LDY #0
	     STA (DISPLAY),Y

SHIFT_DATA   LDY #0
             LDA (DISPLAY),Y
	     ASL A
	     ASL A
	     ASL A
	     ASL A
	     ORA REG_C
	     STA (DISPLAY),Y

	    ; JSR READ_MEMORY
	     JSR STILL_DATA
	     RTS
  
; INCREMENT CURRENT ADDRESS BY ONE
;

KEY_INC     LDA STATE
            CMP #5
	    BEQ REL_KEY_PRESSED

	    CMP #7
	    BEQ SEND_INC1

            LDA #2
            STA STATE     ; STATE =2 FOR DATA MODE

	    LDA #0
	    STA ZERO_FLAG
            

             CLC
             LDA DISPLAY
	     ADC #1
	     STA DISPLAY
	     LDA DISPLAY+1
	     ADC #0
	     STA DISPLAY+1
            ; JSR READ_MEMORY
	     JSR STILL_DATA
	     RTS

REL_KEY_PRESSED
             
	     ; Save start address

	     LDA DISPLAY
	     STA START_ADDRESS
	     LDA DISPLAY+1
	     STA START_ADDRESS+1

             LDA #6
	     STA STATE
             LDA #0
	     STA ZERO_FLAG
	     
	     JSR STILL_ADDRESS
	     LDA #0B3H
	     STA BUFFER
	     LDA #2
	     STA BUFFER+1
	     RTS
    

SEND_INC1   ; Save start address

	     LDA DISPLAY
	     STA START_ADDRESS
	     LDA DISPLAY+1
	     STA START_ADDRESS+1

             LDA #8
	     STA STATE
             LDA #0
	     STA ZERO_FLAG
	     
	     JSR STILL_ADDRESS
	     LDA #08FH
	     STA BUFFER
	     LDA #2
	     STA BUFFER+1
	     RTS







; DECREMENT CURRENT ADDRESS BY ONE
;

KEY_DEC     LDA #2
            STA STATE     ; STATE =2 FOR DATA MODE

	    LDA #0
	    STA ZERO_FLAG
            

             SEC
             LDA DISPLAY
	     SBC #1
	     STA DISPLAY
	     LDA DISPLAY+1
	     SBC #0
	     STA DISPLAY+1
           ;  JSR READ_MEMORY
	     JSR STILL_DATA
	     RTS

; KEY PC, SET CURRENT USER ADDRESS

KEY_PC      LDA #2
            STA STATE     ; STATE =2 FOR DATA MODE

	    LDA #0
	    STA ZERO_FLAG

	    LDA PC_USER
	    STA DISPLAY
	    LDA PC_USER+1       
	    STA DISPLAY+1
           ; JSR READ_MEMORY
	    JSR STILL_DATA
	    RTS

; KEY REGSITER
; SET STATE TO 3 FOR REGISTER INPUT WITH HEX KEY

KEY_REG    LDA #3
           STA STATE  ; STATE = 3 FOR REGISTER DISPLAY

	   LDA #3
	   STA BUFFER+5
	   LDA #8FH
	   STA BUFFER+4
	   LDA #0BEH
	   STA BUFFER+3
	   LDA #2
	   STA BUFFER+2
	   LDA #0
	   STA BUFFER+1
	   STA BUFFER

	   RTS

;---------------------------------------------------------------------------
GO_STATE8
        
	LDA DISPLAY
	STA DESTINATION     ; DESTINATION IS NOW ENDING ADDRESS
	LDA DISPLAY+1
	STA DESTINATION+1

; NOW COMPUTE NUMBER OF BYTE = DESTINATION - START_ADDRESS
        LDA START_ADDRESS
	STA HL
	LDA START_ADDRESS+1
	STA HL+1

        SEC
	LDA DESTINATION
	SBC HL
	STA OFFSET_BYTE

	LDA DESTINATION+1
	SBC HL+1
	STA OFFSET_BYTE+1   ; OFFSET = NUMBER OF BYTE

; DEVIDE NUMBER OF BYTE WITH 16 TO GET NUMBER OF RECORD TO BE SENT

        LSR OFFSET_BYTE+1
	ROR OFFSET_BYTE
        
	LSR OFFSET_BYTE+1
	ROR OFFSET_BYTE

        LSR OFFSET_BYTE+1
	ROR OFFSET_BYTE
        
	LSR OFFSET_BYTE+1
	ROR OFFSET_BYTE

        LDA OFFSET_BYTE ; CHECK RESULT
	STA GPIO1

	RTS

SHORT_GO_STATE10 
        JMP GO_STATE10

; KEY GO WRITE USER REGISTERS TO STACK AND USE RTI TO JUMP TO USER PROGRAM
;

KEY_GO LDA STATE
       CMP #6
       BEQ GO_STATE6

       CMP #8
       BEQ GO_STATE8

       CMP #10
       BEQ SHORT_GO_STATE10

        TSX
	STX SAVE_SP   ; SAVE SYSTEM STACK
	              
; NOW SWITCH TO USER STACK

        LDX USER_S
	TXS          
		
	LDA DISPLAY+1
	PHA
	LDA DISPLAY
	PHA
	LDA USER_P
	PHA
	LDX USER_X
	LDY USER_Y
	LDA USER_A
	RTI
;---------------------- SINGLE STEP ------------------------

KEY_STEP

        TSX
	STX SAVE_SP   ; SAVE SYSTEM STACK
	              
		      ; NOW SWITCH TO USER STACK

        LDX USER_S
	TXS  
	
; LOAD CURRENT PC TO DISPLAY

        LDA PC_USER
	STA DISPLAY
	LDA PC_USER+1
	STA DISPLAY+1



        LDA DISPLAY+1
	PHA
	LDA DISPLAY
	PHA
	LDA USER_P
	PHA
	LDX USER_X
	LDY USER_Y
	
	LDA #$FF       ; BREAK MUST BE LOGIC HIGH TO ENABLE IT
	STA PORT1   
       
       	NOP
	NOP
	NOP
	NOP
	NOP
	LDA USER_A  ; 
	RTI         ; 
	
; USER INSTRUCTION IS 8TH FETCHING, IT WILL JUMP TO NMI SERVICE



; KEY GO WITH RELATIVE CALCULATION
; FIND OFFSET BYTE

GO_STATE6

        LDA DISPLAY
	STA DESTINATION
	LDA DISPLAY+1
	STA DESTINATION+1

; NOW COMPUTE OFFSET_BYTE = DESTINATION - START_ADDRESS

; THE REAL PC WILL BE NEXT INTSRUCTION ADDRESS (+2 FROM BRANCH INSTRUCTION)

        LDA START_ADDRESS
	STA HL
	LDA START_ADDRESS+1
	STA HL+1
	JSR INC_HL
	JSR INC_HL

        SEC
	LDA DESTINATION
	SBC HL
	STA OFFSET_BYTE

	LDA DESTINATION+1
	SBC HL+1
	STA OFFSET_BYTE+1

; CHECK IF THE OFFSET BYTE WAS BETWEEN -128 (FF80) TO +127 (007F)
; IF BIT 7 OF THE OFFSET BYTE IS 0, THE HIGH BYTE MUST BE ZERO
; IF BIT 7 OF THE OFFSET BYTE IS 1, THE HIGH BYTE MUST BE FF
; OTHERWISE, THE OFFSET BYTE WAS OUT OF RANGE, SHOW ERROR THEN

        LDA OFFSET_BYTE
	AND #80H
	BEQ CHK_OFFSET_HIGH

; CHECK HIGH BYTE MUST BE FF (-1)
        
	LDA OFFSET_BYTE+1
	CMP #0FFH
	BNE OUT_OFF_RANGE

	JMP IN_RANGE

CHK_OFFSET_HIGH
        LDA OFFSET_BYTE+1
	BNE OUT_OFF_RANGE

; STORE OFFSET TO THE 2ND BYTE OF BRANCH INSTRUCTION

IN_RANGE LDA START_ADDRESS
	STA HL
	LDA START_ADDRESS+1
	STA HL+1
	JSR INC_HL

	LDA OFFSET_BYTE
	LDY #0
	STA (HL),Y

	LDA HL          ; DISPLAY LOCATION OF OFFSET BYTE
	STA DISPLAY
	LDA HL+1
	STA DISPLAY+1

       
	JSR STILL_DATA

	LDA #2
	STA STATE
	RTS

OUT_OFF_RANGE

        LDA #2
	STA BUFFER+5
	LDA #8FH
	STA BUFFER+4
	LDA #3
	STA BUFFER+3
	LDA #3
	STA BUFFER+2
	LDA #0
	STA BUFFER+1
	STA BUFFER
	
	LDA #2
	STA STATE
	
	RTS







; NMI SERVICE ROUTINE
; SAVE CPU REGISTERS TO USER REGISTERS FOR PROGRAM DEBUGGING

NMI_SERVICE 

         STA USER_A
        ; STA GPIO1     ; 8-BIT DISPLAY WILL SHOW CONTENT OF ACCUMULATOR
	
	 LDA #$BF
	 STA PORT1      ; TURN OFF BRK SIGNAL 

; STILL WITH USER STACK 
	         	  
	 PLA
	 STA USER_P
	 
	 PLA
	 STA DISPLAY
	 STA PC_USER
	 PLA
	 STA DISPLAY+1
	 STA PC_USER+1
	 STY USER_Y
	 STX USER_X
	 
	 TSX 
	 STX USER_S

	 JSR KEY_ADDR ; DISPLAY LOCATION THAT BREAKED

; RESTORE SYSTEM STACK

	 LDX SAVE_SP
	 TXS

	 RTS

; DISPLAY USER REGSITERS

HEX_REG  LDA REG_C
         CMP #0
	 BNE CHK_REG1

	 LDA USER_A
	; STA GPIO1
	 JSR DATA_DISPLAY
	 LDA #82H
	 STA BUFFER+2
	 LDA #3FH        ; REGISTER A
	 STA BUFFER+3
	 LDA #0
	 STA BUFFER+4
	 STA BUFFER+5
	 RTS

CHK_REG1 
         CMP #1
	 BNE CHK_REG2

	 LDA USER_X
	; STA GPIO1

	 JSR DATA_DISPLAY
	 LDA #82H
	 STA BUFFER+2
	 LDA #7         ; REGISTER X
	 STA BUFFER+3
	 LDA #0
	 STA BUFFER+4
	 STA BUFFER+5
	 RTS

CHK_REG2  CMP #2
	 BNE CHK_REG3

	 LDA USER_Y
	; STA GPIO1

	 JSR DATA_DISPLAY
	 LDA #82H
	 STA BUFFER+2
	 LDA #0B6H        ; REGISTER Y
	 STA BUFFER+3
	 LDA #0
	 STA BUFFER+4
	 STA BUFFER+5
	 RTS


CHK_REG3 CMP #3
	 BNE CHK_REG4

	 LDA USER_S
	; STA GPIO1

	 JSR DATA_DISPLAY
	 LDA #82H
	 STA BUFFER+2
	 LDA #0AEH        ; REGISTER S
	 STA BUFFER+3
	 LDA #0
	 STA BUFFER+4
	 STA BUFFER+5
	 RTS

CHK_REG4 CMP #5
         BNE CHK_REG5

	  LDA #0            ; RESET HL TO 0000
	  STA HL
	  STA HL+1

	  LDA USER_P
	 ; STA GPIO1
	  AND #1
	  BEQ NEXT_BIT1
	  LDA HL
	  ORA #1
	  STA HL

NEXT_BIT1 LDA USER_P
          AND #2
	  BEQ NEXT_BIT2

	  LDA HL
	  ORA #10H
	  STA HL

NEXT_BIT2 LDA USER_P
          AND #4
	  BEQ NEXT_BIT3

	  LDA HL+1
	  ORA #1
	  STA HL+1

NEXT_BIT3 LDA USER_P
          AND #8
	  BEQ OK1

	  LDA HL+1
	  ORA #10H
	  STA HL+1
OK1       JSR ADDRESS_DISPLAY
          
	  LDA #1FH
	  STA BUFFER+1
	  LDA #085H
	  STA BUFFER
          RTS


CHK_REG5  CMP #4
          BNE CHK_REG6

          LDA #0            ; RESET HL TO 0000
	  STA HL
	  STA HL+1

	  LDA USER_P
	;  STA GPIO1

	  AND #10H
	  BEQ NEXT_BIT4
	  LDA HL
	  ORA #1
	  STA HL

NEXT_BIT4 LDA USER_P
          AND #20H
	  BEQ NEXT_BIT5
	  LDA HL
	  ORA #10H
	  STA HL

NEXT_BIT5 LDA USER_P
          AND #40H
	  BEQ NEXT_BIT6

	  LDA HL+1
	  ORA #1
	  STA HL+1

NEXT_BIT6 LDA USER_P
          AND #80H
	  BEQ OK2

	  LDA HL+1
	  ORA #10H
	  STA HL+1

OK2       JSR ADDRESS_DISPLAY
          
	  LDA #1FH
	  STA BUFFER+1
	  LDA #37H
	  STA BUFFER
          RTS

CHK_REG6  CMP #10H
          BCS NOT_HEX
	  
; NOW DISPLAY PAGE ZERO BYTE FROM 0 TO 9

          SEC
	  SBC #6

; NOW A IS LOCATION IS PAGE ZERO 0-9
          TAX
	  LDA 0,X
	  STX SAVE_X

	  JSR DATA_DISPLAY
          
	  LDX SAVE_X

	  TXA
	  STA HL+1
	  JSR ADDRESS_DISPLAY

	  LDA #82H
	  STA BUFFER+3
	  LDA #0
	  STA BUFFER+2
	  RTS

NOT_HEX   
          RTS

; PRODUCE BEEP WHEN KEY PRESSED
; CALIBRATED TO 523Hz

BEEP     LDA PORT0    
         AND #40H    
	 BEQ NO_BEEP    ; CHECK IF REPEAT KEY IS PRESSED, THEN NO BEEP

         LDX #40H
BEEP2    LDA #3FH
	 STA PORT1
	 JSR BEEP_DELAY
	 LDA #0BFH
	 STA PORT1
	 JSR BEEP_DELAY

	 DEX
	 BNE BEEP2

NO_BEEP	 RTS

BEEP_DELAY LDY #0BBH      ; 
BEEP_LOOP DEY
          BNE BEEP_LOOP
	  RTS

; DISPLAY COLD BOOT MESSAGE
; 

COLD_MESSAGE 
          
	  LDA #10
          STA REG_D

	  LDA #8
	  STA REG_B

	  LDX #7

DISPLAY2
	  JSR SCAN2

	  DEC REG_D
	  BNE DISPLAY2

	  DEX 

	  DEC REG_B
	  BNE DISPLAY2
	  RTS



 
; NMI and IRQ are called via RAM-vector. This enables the programmer
; to insert his own routines.


NMI    JMP     ($FA)
IRQ    JMP     ($FE)


;-------------------------------------------------------------

MAIN    LDA #0
        STA BUFFER
	STA BUFFER+1
	STA INVALID   ; CLEAR INVALID FLAG

; INSERT 6502 TEXT 

	LDA #0AFH
        STA BUFFER+5
	LDA #0AEH
	STA BUFFER+4
	LDA #0BDH
	STA BUFFER+3
	LDA #9BH
	STA BUFFER+2

	

; STORE VECTOR INTERRUPT
	
	LDA #NMI_SERVICE&0FFH   ; NMI MUST BE SET BEFORE USING SINGLE STEP
	STA $FA
	STA $FE

	LDA #(NMI_SERVICE>>8)
	STA $FB
	STA $FF

	LDX #$FF
	TXS         ; SET SYSTEM STACK TO 1FFH
        LDA #$7F    ; AND USER STACK TO 17FH
	STA USER_S

	CLD
	SEI         ; DISABLE IRQ

	LDA #0
	STA STATE    ; INITIAL STATE
	STA ZERO_FLAG

        LDA #0
	STA DISPLAY
	STA PC_USER
	LDA #02H
	STA DISPLAY+1
	STA PC_USER+1


        LDA DISPLAY
	STA HL
	LDA DISPLAY+1
	STA HL+1



	;JSR ADDRESS_DISPLAY
        LDY #0
	LDA (HL),Y
	;JSR DATA_DISPLAY

        LDA COLD
	CMP #99H
	BEQ WARM_BOOT

	LDA #99H
	STA COLD

	
        LDA #$FF
	STA GPIO1     ; TEST GPIO1

        JSR COLD_MESSAGE
	JSR BEEP

WARM_BOOT
        LDA #0
	STA GPIO1

LOOP3	JSR SCANKEY
        JSR KEYEXE
	JSR BEEP
	JMP LOOP3







;--------------------------------------------------------------
START_MSG .BYTE 0
          .BYTE 0
          .BYTE 9BH
          .BYTE 0BDH
          .BYTE 0AEH
	  .BYTE 0AFH
          .BYTE 0
	  .BYTE 0
	  .BYTE 0
	  .BYTE 0
	  .BYTE 0
          .BYTE 0


SEGTAB	.BYTE	0BDH		;'0'
	.BYTE	030H		;'1'
	.BYTE	09BH		;'2'
	.BYTE	0BAH		;'3'
	.BYTE	036H		;'4'
	.BYTE	0AEH		;'5'
	.BYTE	0AFH		;'6'
	.BYTE	038H		;'7'
	.BYTE	0BFH		;'8'
	.BYTE	0BEH		;'9'
	.BYTE	03FH		;'A'
	.BYTE	0A7H		;'B'
	.BYTE	08DH		;'C'
	.BYTE	0B3H		;'D'
	.BYTE	08FH		;'E'
	.BYTE	00FH		;'F'



; Key-posistion-code to key-internal-code conversion table.

KEYTAB:
K0	.BYTE	03H	;HEX_3
K1	.BYTE	07H	;HEX_7
K2	.BYTE	0BH	;HEX_B
K3	.BYTE	0FH	;HEX_F
K4	.BYTE	20H	;NOT USED
K5	.BYTE	21H	;NOT USED
K6	.BYTE	02H	;HEX_2
K7	.BYTE	06H	;HEX_6
K8	.BYTE	0AH	;HEX_A
K9	.BYTE	0EH	;HEX_E
K0A	.BYTE	22H	;NOT USED
K0B	.BYTE	23H	;NOT USED
K0C	.BYTE	01H	;HEX_1
K0D	.BYTE	05H	;HEX_5
K0E	.BYTE	09H	;HEX_9
K0F	.BYTE	0DH	;HEX_D
K10	.BYTE	13H	;STEP
K11	.BYTE	1FH	;TAPERD
K12	.BYTE	00H	;HEX_0
K13	.BYTE	04H	;HEX_4
K14	.BYTE	08H	;HEX_8
K15	.BYTE	0CH	;HEX_C
K16	.BYTE	12H	;GO
K17	.BYTE	1EH	;TAPEWR
K18	.BYTE	1AH	;CBR
K19	.BYTE	18H	;PC
K1A	.BYTE	1BH	;REG
K1B	.BYTE	19H	;ADDR
K1C	.BYTE	17H	;DEL
K1D	.BYTE	1DH	;RELA
K1E	.BYTE	15H	;SBR
K1F	.BYTE	11H	;-
K20	.BYTE	14H	;DATA
K21	.BYTE	10H	;+
K22	.BYTE	16H	;INS
K23	.BYTE	1CH	;MOVE	

; PAGE FOR CONSTANT STRINGS AREA

	  .ORG 0EF00H        ; ROM MONITOR
          ; .ORG 06F00H        ; RAM TEST 


;TEXT1     .BYTE "6502 TRAINER KIT V1.0 ROM", 10, 13, 0
TEXT1      .BYTE "6502 TRAINER KIT V1.0 RAM", 10, 13, 0 
	

PROMPT     .BYTE ">>", 0
          



	     ; VECTOR NMI,RESET AND IRQ


	  .ORG 0FFFAH

          .WORD  NMI
	  .WORD  0C000H  ; RESET VECTOR
	  .WORD  IRQ        ; IRQ VECTOR




	  .END



