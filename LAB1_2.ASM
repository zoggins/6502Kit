
GPIO1   .EQU $8000

	
	.ORG 200H

         LDA #1
         STA $0

LOOP     LDA $0
         STA GPIO1
         ASL $0

         JMP LOOP

	 .END
