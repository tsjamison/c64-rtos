
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

UM_TS.LOOP

                LDA #$FF
                STA NTID
                LDA #$00
                STA MXPRI
; Check WAITing tasks to see if they received a
; signal for what they were WAITing for.
                LDY MAX_TASKS
-               DEY
                BMI +
                LDA TASK_STATE0,Y
                CMP #TS_WAIT
                BNE -
                LDA WAIT0,Y
                AND SIGNAL0,Y
                BEQ -
                LDA #TS_READY
                STA TASK_STATE0,Y 
                BNE -

; If running then set other READY tasks in same COOP to COOPTED
+               LDY TID
                LDA TASK_STATE0,Y
                CMP #TS_RUN
                BNE UM_TS.NEXT

;running
                STY NTID
                LDA PRI0,y
                STA MXPRI

                LDA COOP0,Y
-               INY
                CPY MAX_TASKS
                BNE +
                LDY #$00
+               CPY TID
                BEQ UM_TS.NEXT
                CMP COOP0,Y
                BNE -
                LDX TASK_STATE0,Y
                CPX #TS_READY
                BNE -
                TAX
                LDA #TS_COOPTED
                STA TASK_STATE0,Y
                TXA
                JMP -

;loop
-               LDA TASK_STATE0,Y
                CMP #TS_READY
                BNE UM_TS.NEXT
                LDA PRI0,Y
                CMP MXPRI
                BCC UM_TS.NEXT   ; Skip if PRI0,Y < MXPRI

; PRI0,Y >= MXPRI
; Best candidate so far
+               STY NTID
                STA MXPRI

UM_TS.NEXT      DEY
                BPL +
                LDY MAX_TASKS
                DEY
+               CPY TID
                BNE -

                CPY NTID
                BEQ TS_SWAP_END
                LDA NTID
                CMP #$FF
                BNE +

; No task selected to run
;                LDA $D011
;                AND #$EF
;                STA $D011
                JMP UM_TS.LOOP

;New Task is different from current Task
;Need to Task Swap
;Update Task State for Running Task and New Task
+               LDA TASK_STATE0,Y
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

TS_SWAP_END     LDA $D011
                ORA #$10
;                STA $D011

                JSR PERMIT
                CLI

                PLA
                TAY
                PLA
                TAX
                PLA
                RTI

