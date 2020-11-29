
GPIO1   .EQU $8000

	
	.ORG 200H

         CLC
	 LDA #$4A
	 AND #$33
         STA $GPIO1
	 BRK


	 .END
