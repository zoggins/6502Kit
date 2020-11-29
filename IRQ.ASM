; Test code for IRQ using 10ms tick
; -how to set irq vectorin RAM
; -display BCD counting on gpio1 every one second
; 

GPIO1   .EQU 8000H
PORT0   .EQU 8001H
PORT1   .EQU 8002H
PORT2   .EQU 8003H


	.ORG $30

SEC100  .BLOCK 1
SEC     .BLOCK 1


        .ORG $FE
        .WORD SERVICE_IRQ

	.ORG 200H

MAIN     LDA #SERVICE_IRQ&$FF
         STA $FE
	 LDA #2
	 STA $FF
        
	 CLI       ; ENABLE IRQ
         JMP $


SERVICE_IRQ

         SED       ; SET DECIMAL MODE
         INC SEC100
	 LDA SEC100
	 CMP #100
	 BNE SKIP1
	 LDA #0
	 STA SEC100
	 
	 CLC
	 LDA SEC
	 ADC #1
         STA SEC       
	 
	 LDA SEC
	 STA GPIO1

SKIP1   
         RTI
         
	 .END

	 .END