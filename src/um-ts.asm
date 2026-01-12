
UM_TS_PROC:	TSX
			INC $101,X
			BNE +
			INC $102,X
+			PHP
			PHA
			PHA
			PHA
			JMP UM_TS

; 6502 Interrupt:
; Push Return address High
; Push Return address low
; Push Status
; JMP ($FFFE) -> FF48
; Push A
; Push X
; Push Y
; Check Status Interrupt bit
; JMP ($0316) if clear (BRK isntruction)
; JMP ($0314) if set

; @todo - Decide if/how to utilise BRK

UM_TS:
                JSR FORBID

                LDY TID
                STY NTID

                LDA #$FF
                STA GROUP
                LDA TASK_STATE0,Y
                CMP #TS_RUN
                BNE +
                LDA GRP0,Y
                STA GROUP

+               LDA #$00
                STA MXPRI

-               LDA TASK_STATE0,Y
                BEQ UM_TS.NEXT

                CPY TID
                BEQ +
                LDA GRP0,Y
                CMP GROUP
                BEQ UM_TS.NEXT

+               LDA WAIT0,Y
                BEQ +
                AND SIGNAL0,Y
                BEQ UM_TS.NEXT

+               LDA PRI0,Y
                CMP MXPRI
                BMI UM_TS.NEXT     ; maybe BCC or BCS?

                STY NTID
                STA MXPRI

UM_TS.NEXT      DEY
                BPL +
                LDY MAX_TASKS
                DEY
+
                CPY TID
                BNE -    ;DONE with LOOP

                CPY NTID
                BEQ TS_SWAP_END

;New Task is different from current Task
;Need to Task Swap
;Update Task State for Running Task and New Task
                LDA TASK_STATE0,Y
                CMP #TS_RUN
                BNE +
                LDA #TS_READY
                STA TASK_STATE0,Y
+               LDY NTID
                LDA #TS_RUN
                STA TASK_STATE0,Y

;DO TASK SWAP
                TSX
                TXA
                LDY TID
                STA SP0,Y

                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_SAVE
                LDX TID
                SEI
                JMP XFER_BASIC_XY 

+               LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH

                LDY #XFER_LOAD
                LDX NTID
                STX TID
                STX $D020
                JMP XFER_BASIC_XY

+               LDY TID
                LDX SP0,Y
                TXS

TS_SWAP_END     JSR PERMIT
                CLI

                PLA
                TAY
                PLA
                TAX
                PLA
                RTI

