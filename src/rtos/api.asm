
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

;INPUT : A-Y   A = co-op (0-15), Y = task
;OUTPUT: ---
;USED  : AX-
SET_COOP        AND #mxcoops-1
                SEI
                PHA
                JSR COOP_RELEASE    ; leave the old co-op
                PLA
                STA COOP0,Y
                LDA TASK_STATE0,Y   ; a running task takes its new co-op
                CMP #TS_RUN         ; if it is free. If another task holds
                BNE +               ; it, the scheduler switches this one out
                LDX COOP0,Y
                LDA COOP_OWNER,X
                BPL +
                TYA
                STA COOP_OWNER,X
+               CLI
                RTS

;INPUT : -X-
;OUTPUT: --Y
;USED  : ---
GET_COOP         LDY COOP0,X
                RTS

; TS_COOPTED and TS_PREEMPT are not stored. A READY task reports
; TS_PREEMPT if it holds its co-op (it was pre-empted while
; running) or TS_COOPTED if another task holds it.
;INPUT : -X-
;OUTPUT: --Y
;USED  : A--
GET_STATE       LDY TASK_STATE0,X
                CPY #TS_READY
                BNE +++
                LDY COOP0,X
                LDA COOP_OWNER,Y
                BMI ++           ; co-op free: plain READY
                TXA
                CMP COOP_OWNER,Y
                BNE +
                LDY #TS_PREEMPT
                RTS
+               LDY #TS_COOPTED
                RTS
+               LDY #TS_READY
+               RTS

;INPUT : A--
;OUTPUT: A--
;USED  : -XY
WAIT            LDY TID
                STA WAIT0,Y
                JSR COOP_RELEASE    ; let the co-op's other tasks run
                LDA WAIT0,Y
                BEQ +
                LDA #TS_WAIT        ;wait/sleep (can select lower priority)
                STA TASK_STATE0,Y
                BNE ++
+               LDA #TS_READY       ;YIELD (can't select lower priority)
                STA TASK_STATE0,Y

                ; Going to Sleep
+               JSR UM_TS_PROC
                ; Waking up from Sleep
                LDY TID
                SEI                 ; mask IRQs for the read-modify-write
                LDA WAIT0,Y
                AND SIGNAL0,Y
                TAX                 ; X = signals that woke us
                LDA WAIT0,Y
                EOR #$FF
                AND SIGNAL0,Y
                STA SIGNAL0,Y
                CLI
                LDA #$00
                STA WAIT0,Y
                TXA
                RTS

;INPUT : A-Y
;OUTPUT: A--
;USED  : ---
SIGNAL          SEI                 ; mask IRQs for the read-modify-write
                ORA SIGNAL0,Y
                STA SIGNAL0,Y
                LDA WAIT0,Y
                AND SIGNAL0,Y
                CLI
                BEQ +
                TYA                 ; UM_TS_PROC does not preserve Y,
                PHA                 ; so keep the task ID on our stack
                JSR UM_TS_PROC      ; reschedule
                PLA
                TAY
+               LDA SIGNAL0,Y       ; return the task's signal set
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
                STY ENQUEUE_L
                STX ENQUEUE_T

                LDX QTAIL
                LDY #$00
                CPY ENQUEUE_L
                BEQ ENQ_EMPTY       ; nothing to enqueue
-               LDA (INDEX1),Y
                STA QDATA0,X
                INX
                INY
                CPX QHEAD
                BEQ +
                CPY ENQUEUE_L
                BNE -
                BEQ ++
+               DEX
                DEY
+               STX QTAIL

                LDX ENQUEUE_T
                SEI
                LDA #QUEUE_SIGNAL
                ORA SIGNAL0,X
                STA SIGNAL0,X
                CLI
ENQ_EMPTY       RTS

;Parameter: A = Length requested
;Return Y = Length received
;(DSCTMP+1) = ptr to string (allocated as BASIC string)
DEQUEUE:
                STA DEQUEUE_L
                CMP #$00
                BEQ DQ_ZERO
                LDX QTAIL               
                CPX QHEAD               ; If there are bytes
                BNE +                   ; Then don't wait
                LDA #QUEUE_SIGNAL       ; Wait for bytes
                JSR WAIT
+               SEC
                LDA QTAIL
                SBC QHEAD               ; Calculate # bytes received
                CMP DEQUEUE_L
                BCS +                   ; skip if Received >= Requested
                STA DEQUEUE_L           ; Less than requested
+               LDA DEQUEUE_L           ; Get # bytes to return
DQ_ZERO         JSR STRSPA              ; Allocate BASIC string variable
                LDX QHEAD               ; X = Source Index
                LDY #$00                ; Y = Destination Index

                CPY DEQUEUE_L
                BEQ +

-               LDA QDATA0,X            ; Get a byte
                STA (DSCTMP+1),Y        ; Store a byte
                INX
                INY
                CPY DEQUEUE_L
                BNE -                   ; Loop until all bytes copied
                STX QHEAD               ; Update QHEAD
+               LDY TID
                SEI
                LDA SIGNAL0,Y
                AND #~QUEUE_SIGNAL
                STA SIGNAL0,Y
                CLI
                LDY DEQUEUE_L
                RTS



; NEWL = Low Byte of start
; NEWH = High Byte of start
; FORK_FLAG = non-zero = FORK, zero = AddTask
NEW_TASK:
                JSR FORBID
 
                STA NEWL
                STY NEWH
                STX FORK_FLAG

; save stack pointer
                TSX
                TXA
                LDY TID
                STA SP0,Y

                LDA FORK_FLAG   ; non-zero = FORK
                BNE +           ; zero = AddTask

                LDX #$FF
                TXS

; Put END_TASK as RTS
                LDA #>END_TASK
                PHA
                LDA #<END_TASK-1
                PHA

; Put GET_TID as RTI for new task
+               LDA FORK_FLAG
                BEQ +
                PLA
                PLA
+               LDA NEWH
                PHA
                LDA NEWL
                PHA
                LDA #$20
                PHA
                LDA #$00
                PHA
                PHA
                PHA

; Find next empty slot
                LDY TID
-               INY
                CPY MAX_TASKS
                BNE +
                LDY #$00
+               CPY TID
                BNE +
                LDX #16   ; OUT OF MEMORY ERROR
                JMP ERROR
+               LDA TASK_STATE0,Y
                BNE -

                STY NTID
                LDA #TS_READY
                STA TASK_STATE0,Y
                LDA #$01           ; new task starts with FORBID count 0
                STA FORBID0,Y
                TSX
                TXA
                STA SP0,Y

; Duplicate current task's memory for new task
                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_SAVE
                JMP XFER_BASIC_XY

+               LDY TID
                LDX SP0,Y
                TXS
                JSR PERMIT

GET_TID         LDY TID
                RTS

; @todo Update addtask to work correctly
; A is low
; Y is high
FORK
; save stack pointer
                LDA #<GET_TID
                LDY #>GET_TID
                LDX #$FF
                JMP NEW_TASK

; @todo Update addtask to work correctly
; A is low
; Y is high
addtask
; save stack pointer
                LDX #$00
                JMP NEW_TASK

; @todo - NEEDS UPDATED
END_TASK:
                LDY TID
                SEI
                JSR COOP_RELEASE    ; free its co-op first
                LDA #TS_INVALID
                STA TASK_STATE0,Y
                CLI
                JSR UM_TS_PROC   ; Will never come back
