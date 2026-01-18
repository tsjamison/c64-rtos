
;INPUT : ---
;OUTPUT: ---
;USED  : ---
FORBID          INC TS_ENABLE
                RTS


;INPUT : ---
;OUTPUT: ---
;USED  : A--
PERMIT          SEI
                LDA TS_ENABLE
                BEQ +
                DEC TS_ENABLE
+               CLI
                RTS

;INPUT : A-Y
;OUTPUT: ---
;USED  : ---
SET_PRI         STA PRI0,Y
                RTS

;INPUT : -X-
;OUTPUT: --Y
;USED  : ---
GET_PRI         LDY PRI0,X
                RTS

;INPUT : A-Y
;OUTPUT: ---
;USED  : ---
SET_GRP         STA GRP0,Y
                RTS

;INPUT : -X-
;OUTPUT: --Y
;USED  : ---
GET_GRP         LDY GRP0,X
                RTS

;INPUT : -X-
;OUTPUT: --Y
;USED  : ---
GET_STATE       LDY TASK_STATE0,X
                RTS

;INPUT : A--
;OUTPUT: A--
;USED  : -XY
WAIT            LDY TID
                STA WAIT0,Y
                LDA #TS_WAIT
                STA TASK_STATE0,Y
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

;INPUT : A-Y
;OUTPUT: A--
;USED  : ---
SIGNAL 			ORA SIGNAL0,Y
				STA SIGNAL0,Y
				RTS

;INPUT : A-Y
;OUTPUT: A--
;USED  : -XY
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

;INPUT : --Y
;OUTPUT: AXY
;USED  : ---
WAIT_MEMORY:
                LDY TID
                LDA ANDMSK
                STA ANDMSK0,Y
                LDA EORMSK
                STA EORMSK0,Y
                TYA
                ASL
                TAY
                LDA POKER+0
                STA POKER0+0,Y
                LDA POKER+1
                STA POKER0+1,Y
                LDA #WAITM_SIGNAL
                JSR WAIT

                LDX TID
                LDY WAITM0,X
                RTS

;INPUT : -XY
;OUTPUT: A--
;USED  : -XY

;Y = Length
;X = Task to signal
;INDEX1 = Address to get data from
ENQUEUE:
                STY NEWL
                STX NEWH

                LDX QTAIL
                LDY #$00
-               LDA (INDEX1),Y
                STA QDATA0,X
                INX
                INY
                CPX QHEAD
                BEQ +
                CPY NEWL
                BNE -
                BEQ ++
+               DEX
                DEY
+               STX QTAIL

                LDX NEWH
                LDA #QUEUE_SIGNAL
                ORA SIGNAL0,X
                STA SIGNAL0,X
                RTS

;Y = Length
;INDEX1 Address to put data to
DEQUEUE:
                TYA
                PHA
                LDA #QUEUE_SIGNAL
                JSR WAIT

                PLA
                STA NEWL

                SEC
                LDA QTAIL
                SBC QHEAD
                CMP NEWL
                BCS +
                STA NEWL
                BCC ++
+               LDA NEWL
+               JSR STRSPA
                LDX QHEAD
                LDY #$00
-               LDA QDATA0,X
                STA (DSCTMP+1),Y
                INX
                INY
                CPY NEWL
                BNE -
                STX QHEAD
                CPX QTAIL
                BEQ +
                LDA #QUEUE_SIGNAL
                LDX TID
                ORA SIGNAL0,X
                STA SIGNAL0,X
		; Remove the RTS address for function from the stack
		; to avoid Type Mismatch error
+               PLA
                PLA
                JMP PUTNEW



FORK:
; save stack pointer
                JSR FORBID

                TSX
                TXA
                LDY TID
                STA SP0,Y

; Put GET_TID as RTI for new task
                LDA #>GET_TID
                PHA
                LDA #<GET_TID
                PHA
                LDA #$20
                PHA
                LDA #$00
                PHA
                PHA
                PHA

; Find next empty slot
                LDX TID
-               INX
                CPX MAX_TASKS
                BNE +
                LDX #$00
+               CPX TID
                BNE +
                LDX #16   ; OUT OF MEMORY ERROR
                JMP ERROR
+               LDA TASK_STATE0,X
                BNE -

                STX NTID
                LDA #TS_READY
                STA TASK_STATE0,X

; Duplicate current task's memory for new task
                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_SAVE
                JMP XFER_BASIC_XY

+               LDY NTID
                TSX
                TXA
                STA SP0,Y

                LDY TID
                LDX SP0,Y
                TXS
                JSR PERMIT

GET_TID         LDY TID
                RTS

; @todo Update addtask to work correctly
; A is low
; Y is high
addtask
; save stack pointer
                STA NEWL
                STY NEWH
                JSR FORBID

                TSX
                TXA
                LDX TID
                STA SP0,X

; Save current task's memory so new task can be created
; without affecting current task
                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_SAVE
                JMP XFER_BASIC_XY

+               LDX #$FF
                TXS

; Put Removetask as RTS
                LDA #>END_TASK
                PHA
                LDA #<END_TASK-1
                PHA

                LDA NEWL
                PHA
                LDA NEWH
                PHA
                LDA #$20
                PHA
                LDA #$00
                PHA
                PHA
                PHA

; Find next empty slot
                LDX TID
-               INX
                CPX MAX_TASKS
                BNE +
                LDX #$00
+               CPX TID
                BNE +
                LDX #16   ; OUT OF MEMORY ERROR
                JMP ERROR
+               LDA TASK_STATE0,X
                BNE -

                STX NTID
                LDA #TS_READY
                STA TASK_STATE0,X

; Save new task's memory
                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_SAVE
                JMP XFER_BASIC_XY

+               LDY NTID
                TSX
                TXA
                STA SP0,Y

; Load original task's memory
                LDY TID
                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_LOAD
                JMP XFER_BASIC_XY

+               LDX SP0,Y
                TXS
                JSR PERMIT
                LDY NTID
                RTS


; @todo - NEEDS UPDATED
END_TASK:
                LDA #TS_INVALID
                LDY TID
                STA TASK_STATE0,Y
                JSR UM_TS_PROC   ; Will never come back
