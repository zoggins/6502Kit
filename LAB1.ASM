
GPIO1   .EQU $8000

	
	.ORG 200H

         LDA #0
         STA $0

LOOP     LDA $0
         STA GPIO1
         INC $0

         JMP LOOP

	 .END
