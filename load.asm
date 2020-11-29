
GPIO1   .EQU $8000

	
	.ORG 200H

         LDA $0
         STA $GPIO1
	 BRK


	 .END
