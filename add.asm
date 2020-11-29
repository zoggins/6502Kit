
GPIO1   .EQU $8000

	
	.ORG 200H

         CLC
	 LDA #%01011011
	 ADC #%01011010
         STA $GPIO1
	 BRK


	 .END
