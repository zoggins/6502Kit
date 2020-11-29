
GPIO1   .EQU 8000H
PORT0   .EQU 8001H
PORT1   .EQU 8002H
PORT2   .EQU 8003H

	
	.ORG 200H

MAIN2	 LDA #1
         STA 0
LOOP         
	 ROL 0
         LDA 0
	 STA GPIO1
    	 JMP LOOP
         
	 .END


	 .END