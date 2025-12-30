
FORBID          INC TS_ENABLE
                RTS

PERMIT          SEI
                LDA TS_ENABLE
                BEQ +
                DEC TS_ENABLE
                CLI
                RTS

SET_PRI         STA PRI0,Y
                RTS

GET_PRI         LDY PRI0,X
                RTS

WAIT            LDY TID
                STA WAIT0,Y
                ; Going to Sleep
                JSR UM_TS_PROC
                ; Waking up from Sleep
                LDY TID
                LDA WAIT0,Y
                AND SIGNAL0,Y
                PHA
                LDA WAIT0,Y
                EOR #$FF
                AND SIGNAL0,Y
                STA SIGNAL0,Y
                LDA #$00
                STA WAIT0,Y
                PLA
                RTS

SIGNAL 			ORA SIGNAL0,Y
				STA SIGNAL0,Y
				RTS

SLEEP
                LDX TID
                STA SLEEP1,X
                TYA
                STA SLEEP0,X
                ORA SLEEP1,X
                BEQ +
                LDA #TIMER_SIGNAL
                BNE ++
+               LDA #$00
+               JSR WAIT
                RTS



; @todo Update addtask to work correctly
addtask
;SAVE CURRENT STACK POINTER
                TSX
                STX SP0
; SET UP TASK1 RTS DESTINATION
                LDX #$7F
                TXS
                LDA #>CLEANUP
                PHA
                LDA #<CLEANUP-1
                PHA

; SET UP TASK1 START
;               LDA #>TASK1
                PHA
;               LDA #<TASK1
                PHA
                LDA #$20
                PHA       ;STATUS REGISTER
                LDA #$00
                PHA       ;ACC
                PHA       ;X
                PHA       ;Y
                TSX
;               STX SP1
    
;               STA FLG1  ;SET ENABLE FLAG
                LDX SP0
                TXS
                RTS

