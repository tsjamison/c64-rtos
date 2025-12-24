
FORBID          INC TS_ENABLE
                RTS

PERMIT          LDA TS_ENABLE
                BEQ +
                DEC TS_ENABLE
                RTS

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
                STX SP1
    
                STA FLG1  ;SET ENABLE FLAG
                LDX SP0
                TXS
                RTS

