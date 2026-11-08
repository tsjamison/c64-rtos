
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
; signal for what they were WAITing for. A woken task is
; READY; COOP_OK decides below whether its co-op lets it run.
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
                BNE -   ; BRA

; If the current task is running and its co-op still lets it
; run, it is the candidate to beat
+               LDY TID
                LDA TASK_STATE0,Y
                CMP #TS_RUN
                BNE +
                JSR COOP_OK
                BCS +   ; moved into a co-op another task holds
                STY NTID
                LDA PRI0,Y
                STA MXPRI
                JMP UM_TS.NEXT

;loop: highest-priority READY task that its co-op allows
+
-               LDA TASK_STATE0,Y
                CMP #TS_READY
                BNE UM_TS.NEXT
                LDA PRI0,Y
                CMP MXPRI
                BCC UM_TS.NEXT   ; Skip if PRI0,Y < MXPRI
                JSR COOP_OK
                BCS UM_TS.NEXT   ; another task holds its co-op

; PRI0,Y >= MXPRI
; Best candidate so far
                STY NTID
                LDA PRI0,Y
                STA MXPRI

UM_TS.NEXT      DEY
                BPL +
                LDY MAX_TASKS
                DEY
+               CPY TID
                BNE -

                LDA NTID
                CMP #$FF
                BNE +

; No task selected to run
                LDA $D011
                AND #$EF
                STA $D011
                JMP UM_TS.LOOP

;New Task is different from current Task
;Need to Task Swap
;Update Task State for Running Task and New Task.
;A pre-empted task goes back to READY but keeps its co-op.
+               LDA TASK_STATE0,Y
                CMP #TS_RUN
                BNE +
                LDA #TS_READY
                STA TASK_STATE0,Y
+               LDY NTID
                LDA #TS_RUN
                STA TASK_STATE0,Y
                LDX COOP0,Y      ; new task takes its co-op
                TYA
                STA COOP_OWNER,X

                LDY TID
                CPY NTID
                BEQ TS_SWAP_END

;DO TASK SWAP
                TSX
                TXA
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
                STA $D011

                JSR PERMIT
                CLI

                PLA
                TAY
                PLA
                TAX
                PLA
                RTI

; Can task Y run as far as its co-op is concerned?
; Carry clear = yes: the co-op is free, or Y already holds it.
;INPUT : --Y
;OUTPUT: C
;USED  : AX-
COOP_OK         LDX COOP0,Y
                LDA COOP_OWNER,X
                BMI +            ; $FF: co-op is free
                TYA
                CMP COOP_OWNER,X
                BNE ++           ; another task holds it
+               CLC
                RTS
+               SEC
                RTS

; Task Y gives up its co-op, if it holds it.
;INPUT : --Y
;OUTPUT: ---
;USED  : AX-
COOP_RELEASE    LDX COOP0,Y
                TYA
                CMP COOP_OWNER,X
                BNE +
                LDA #$FF
                STA COOP_OWNER,X
+               RTS
