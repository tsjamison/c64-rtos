;========================================================================
; api.asm - the assembly-language API (reached through the jump table)
;
; Register conventions are not uniform yet: GET_* take the task ID in X,
; SET_* and SIGNAL take it in Y, and SLEEP takes its 16-bit value as
; A = hi, Y = lo. See the coding standards review before relying on them.
;========================================================================

;------------------------------------------------------------------------
; FORBID - stop task switching until a matching PERMIT. Nests.
; In:   -
; Out:  -
; Uses: N Z
;------------------------------------------------------------------------
FORBID          INC TS_ENABLE
                RTS

;------------------------------------------------------------------------
; PERMIT - undo one FORBID. Does nothing if the level is already 0.
; In:   -
; Out:  -
; Uses: A
; Note: always ends with CLI, even if IRQs were masked on entry
;------------------------------------------------------------------------
PERMIT          SEI
                LDA TS_ENABLE
                BEQ +
                DEC TS_ENABLE
+               CLI
                RTS

;------------------------------------------------------------------------
; SET_PRI - set a task's priority. Higher priority runs first.
; In:   A = priority, Y = task ID
; Out:  -
; Uses: -
;------------------------------------------------------------------------
SET_PRI         STA PRI0,Y
                RTS

;------------------------------------------------------------------------
; GET_PRI - get a task's priority.
; In:   X = task ID
; Out:  Y = priority
; Uses: Y
;------------------------------------------------------------------------
GET_PRI         LDY PRI0,X
                RTS

;------------------------------------------------------------------------
; SET_COOP - move a task to a co-op, releasing the co-op it was in.
;       A running task takes its new co-op if it is free. If another
;       task holds it, the scheduler switches this one out.
; In:   A = co-op (masked to 0-15), Y = task ID
; Out:  -
; Uses: A X
; Note: ends with CLI
;------------------------------------------------------------------------
SET_COOP        AND #MXCOOPS-1
                SEI
                PHA
                JSR COOP_RELEASE        ; leave the old co-op
                PLA
                STA COOP0,Y
                LDA TASK_STATE0,Y       ; a running task takes its new co-op
                CMP #TS_RUN             ; if it is free
                BNE +
                LDX COOP0,Y
                LDA COOP_OWNER,X
                BPL +                   ; held by another task
                TYA
                STA COOP_OWNER,X
+               CLI
                RTS

;------------------------------------------------------------------------
; GET_COOP - get a task's co-op.
; In:   X = task ID
; Out:  Y = co-op
; Uses: Y
;------------------------------------------------------------------------
GET_COOP        LDY COOP0,X
                RTS

;------------------------------------------------------------------------
; GET_STATE - get a task's state, as returned by USR(14).
;       TS_COOPTED and TS_PREEMPT are not stored. A READY task reports
;       TS_PREEMPT if it holds its co-op (it was pre-empted while
;       running) or TS_COOPTED if another task holds it.
; In:   X = task ID
; Out:  Y = TS_xxx
; Uses: A Y
;------------------------------------------------------------------------
GET_STATE       LDY TASK_STATE0,X
                CPY #TS_READY
                BNE _done               ; not READY: stored state
                LDY COOP0,X
                LDA COOP_OWNER,Y
                BMI _ready              ; co-op free: plain READY
                TXA
                CMP COOP_OWNER,Y
                BNE _coopted
                LDY #TS_PREEMPT         ; it holds its own co-op
                RTS
_coopted        LDY #TS_COOPTED         ; another task holds it
                RTS
_ready          LDY #TS_READY
_done           RTS

;------------------------------------------------------------------------
; WAIT - sleep until any of the signals in A arrives.
;       Releases the task's co-op. A = 0 yields: the task stays READY
;       and runs again at once, unless another task of equal or higher
;       priority can run. Signals that arrived before the call satisfy
;       it without waiting, but the call still goes through the
;       scheduler, so it yields in the same way.
; In:   A = signal mask (0 = yield)
; Out:  A = the signals in the mask that woke the task (now cleared)
; Uses: A X Y
; Switches tasks: yes
; Note: ends with CLI
;------------------------------------------------------------------------
WAIT            LDY TID
                STA WAIT0,Y
                JSR COOP_RELEASE        ; let the co-op's other tasks run
                LDA WAIT0,Y
                BEQ +
                LDA #TS_WAIT            ; wait/sleep (can select lower priority)
                STA TASK_STATE0,Y
                BNE ++                  ; always taken
+               LDA #TS_READY           ; yield (can't select lower priority)
                STA TASK_STATE0,Y

                ; Going to sleep
+               JSR UM_TS_PROC
                ; Waking up
                LDY TID
                SEI                     ; mask IRQs for the read-modify-write
                LDA WAIT0,Y
                AND SIGNAL0,Y
                TAX                     ; X = signals that woke us
                LDA WAIT0,Y
                EOR #$FF
                AND SIGNAL0,Y
                STA SIGNAL0,Y           ; clear them
                CLI
                LDA #$00
                STA WAIT0,Y
                TXA
                RTS

;------------------------------------------------------------------------
; SIGNAL - post signals to a task. If it was waiting for any of them,
;       reschedule at once.
; In:   A = signals, Y = task ID
; Out:  A = the task's signal set after posting
; Uses: A X
; Switches tasks: yes, if the task was waiting for one of the signals
; Note: ends with CLI
;------------------------------------------------------------------------
SIGNAL          SEI                     ; mask IRQs for the read-modify-write
                ORA SIGNAL0,Y
                STA SIGNAL0,Y
                LDA WAIT0,Y
                AND SIGNAL0,Y
                CLI
                BEQ +
                TYA                     ; UM_TS_PROC does not preserve Y,
                PHA                     ; so keep the task ID on our stack
                JSR UM_TS_PROC          ; reschedule
                PLA
                TAY
+               LDA SIGNAL0,Y           ; return the task's signal set
                RTS

;------------------------------------------------------------------------
; SLEEP - sleep the running task for a number of jiffies.
;       0 jiffies just yields.
; In:   A = jiffies hi, Y = jiffies lo   (note: hi in A, unlike NEW_TASK)
; Out:  A = signals that woke the task (TIMER_SIGNAL, or 0 for a yield)
; Uses: A X Y
; Switches tasks: yes
;------------------------------------------------------------------------
SLEEP           LDX TID
                SEI
                STA SLEEP1,X
                TYA
                STA SLEEP0,X
                ORA SLEEP1,X
                CLI
                BEQ +
                LDA #TIMER_SIGNAL
                BNE ++                  ; always taken
+               LDA #$00                ; 0 jiffies: yield
+               JSR WAIT
                RTS

;------------------------------------------------------------------------
; WAIT_MEMORY - sleep until (PEEK(address) EOR eor) AND and is non-zero,
;       like BASIC's WAIT. INT tests the address every jiffy.
; In:   POKER  ($14/$15) = address
;       ANDMSK ($49)     = AND mask
;       EORMSK ($4A)     = EOR mask
; Out:  Y = (PEEK(address) EOR eor) AND and, as INT found it
;       X = running task ID
;       A = signals that woke the task
; Uses: A X Y
; Switches tasks: yes
;------------------------------------------------------------------------
WAIT_MEMORY     LDY TID
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

;------------------------------------------------------------------------
; ENQUEUE - add bytes to the global queue and signal a task.
;       If the queue fills, only the bytes that fit are added.
;       Not in the jump table yet; USR(11) has its own copy (USR_NQ).
; In:   INDEX1 ($22/$23) = address of the data
;       Y = length, X = task to send QUEUE_SIGNAL to
; Out:  Y = bytes added
; Uses: A X Y
; Note: ends with CLI when Y > 0
;------------------------------------------------------------------------
ENQUEUE         STY ENQUEUE_L
                STX ENQUEUE_T

                LDX QTAIL
                LDY #$00
                CPY ENQUEUE_L
                BEQ _empty              ; nothing to enqueue
-               LDA (INDEX1),Y
                STA QDATA0,X
                INX
                INY
                CPX QHEAD
                BEQ +                   ; queue full
                CPY ENQUEUE_L
                BNE -
                BEQ ++                  ; always taken
+               DEX                     ; full: take back the last byte
                DEY
+               STX QTAIL

                LDX ENQUEUE_T
                SEI
                LDA #QUEUE_SIGNAL
                ORA SIGNAL0,X
                STA SIGNAL0,X
                CLI
_empty          RTS

;------------------------------------------------------------------------
; DEQUEUE - take up to A bytes from the global queue as a new BASIC
;       string. Waits if the queue is empty (unless A = 0).
;       Used by USR(12). Open issue 2: see the code analysis.
; In:   A = most bytes wanted
; Out:  Y = bytes returned
;       DSCTMP ($61-$63) = string descriptor from STRSPA (length, address)
; Uses: A X Y
; Switches tasks: yes, when the queue is empty
; Note: ends with CLI
;------------------------------------------------------------------------
DEQUEUE         STA DEQUEUE_L
                CMP #$00
                BEQ _zero
                LDX QTAIL
                CPX QHEAD               ; if there are bytes
                BNE +                   ; then don't wait
                LDA #QUEUE_SIGNAL       ; wait for bytes
                JSR WAIT
+               SEC
                LDA QTAIL
                SBC QHEAD               ; bytes in the queue
                CMP DEQUEUE_L
                BCS +                   ; skip if available >= requested
                STA DEQUEUE_L           ; fewer than requested
+               LDA DEQUEUE_L           ; bytes to return
_zero           JSR STRSPA              ; allocate the BASIC string
                LDX QHEAD               ; X = source index
                LDY #$00                ; Y = destination index

                CPY DEQUEUE_L
                BEQ +

-               LDA QDATA0,X            ; get a byte
                STA (DSCTMP+1),Y        ; store a byte
                INX
                INY
                CPY DEQUEUE_L
                BNE -                   ; loop until all bytes copied
                STX QHEAD               ; update QHEAD
+               LDY TID
                SEI
                LDA SIGNAL0,Y
                AND #~QUEUE_SIGNAL
                STA SIGNAL0,Y
                CLI
                LDY DEQUEUE_L
                RTS


;------------------------------------------------------------------------
; NEW_TASK - common code for FORK and ADD_TASK.
;       Builds an interrupt frame that starts the new task at the given
;       address, finds a free task slot, and copies the running task's
;       memory into the new task's REU bank.
; In:   A = start address lo, Y = start address hi
;       X = non-zero for FORK, 0 for ADD_TASK
; Out:  Y = task ID (see FORK). Falls through into GET_TID.
; Uses: A X Y
; Errors: no free slot -> BASIC ?OUT OF MEMORY ERROR (does not return,
;       and FORBID is still held)
; Note: unlike USR_FORK, does not clear the new task's sleep timer,
;       signals and wait mask, or copy the priority and co-op
;------------------------------------------------------------------------
NEW_TASK        JSR FORBID

                STA NEWL
                STY NEWH
                STX FORK_FLAG

; Save the stack pointer
                TSX
                TXA
                LDY TID
                STA SP0,Y

                LDA FORK_FLAG
                BNE _frame              ; FORK: build on the current stack

; ADD_TASK: start a fresh stack whose final RTS goes to END_TASK
; (@todo: this overwrites the top of the running task's stack)
                LDX #$FF
                TXS
                .cerror <END_TASK == 0, "END_TASK-1 crosses a page: push >(END_TASK-1)"
                LDA #>END_TASK
                PHA
                LDA #<END_TASK-1
                PHA

; Push a fake interrupt frame that starts the new task at NEWH/NEWL
_frame          LDA FORK_FLAG
                BEQ +
                PLA                     ; FORK: drop the caller's return
                                        ; address (@todo: see FORK)
                PLA
+               LDA NEWH
                PHA
                LDA NEWL
                PHA
                LDA #FAKE_P
                PHA
                LDA #$00                ; A, X, Y
                PHA
                PHA
                PHA

; Find the next empty slot
                LDY TID
-               INY
                CPY MAX_TASKS
                BNE +
                LDY #$00
+               CPY TID
                BNE +
                LDX #ERR_OUT_OF_MEMORY  ; every slot is in use
                JMP ERROR
+               LDA TASK_STATE0,Y
                BNE -

                STY NTID
                LDA #TS_READY
                STA TASK_STATE0,Y
                LDA #$01                ; FORBID count 0, plus the 1 the scheduler's
                STA FORBID0,Y           ; PERMIT takes off when it first runs the task
                TSX
                TXA
                STA SP0,Y

; Duplicate the current task's memory for the new task
                LDA #<_copied
                STA XFER_RET
                LDA #>_copied
                STA XFER_RET+1
                LDY #XFER_SAVE
                JMP XFER_BASIC_XY

_copied         LDY TID
                LDX SP0,Y
                TXS
                JSR PERMIT

;------------------------------------------------------------------------
; GET_TID - get the running task's ID.
; In:   -
; Out:  Y = task ID
; Uses: Y
;------------------------------------------------------------------------
GET_TID         LDY TID
                RTS

;------------------------------------------------------------------------
; FORK - start a copy of the running task. The parent returns to the
;       caller with its own ID in Y.
;       @todo The child starts at GET_TID, but its RTS skips the caller
;       and returns to the caller's caller: NEW_TASK drops the caller's
;       return address before building the child's frame.
; In:   -
; Out:  Y = task ID: the parent gets its own ID, the child the new ID
; Uses: A X Y
; Errors: see NEW_TASK
;------------------------------------------------------------------------
FORK            LDA #<GET_TID           ; the child starts at GET_TID
                LDY #>GET_TID
                LDX #$FF                ; non-zero: FORK
                JMP NEW_TASK

;------------------------------------------------------------------------
; ADD_TASK - start a new task at an address.
;       @todo Update ADD_TASK to work correctly
; In:   A = start address lo, Y = start address hi
; Out:  Y = task ID
; Uses: A X Y
; Errors: see NEW_TASK
;------------------------------------------------------------------------
ADD_TASK        LDX #$00                ; 0: ADD_TASK
                JMP NEW_TASK

;------------------------------------------------------------------------
; END_TASK - end the running task. Does not return.
;       @todo NEEDS UPDATING
; In:   -
; Switches tasks: yes
;------------------------------------------------------------------------
END_TASK        LDY TID
                SEI
                JSR COOP_RELEASE        ; free its co-op first
                LDA #TS_INVALID
                STA TASK_STATE0,Y
                CLI
                JSR UM_TS_PROC          ; never comes back
