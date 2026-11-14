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
; Queues. Each task has its own QSIZE-byte ring buffer in QDATA0, at
; offset task ID * QSIZE. Any task can add to any task's queue; only the
; owner takes bytes out, so only the owner moves QHEAD0 and lowers QLEN0.
; QUEUE_SIGNAL is up while the owner's queue has bytes in it. Calls can
; move up to 255 bytes: writers wait for QSPACE_SIGNAL when the queue is
; full, the owner waits for QUEUE_SIGNAL when it is empty. The progress
; of each call is kept per task (NQ_xxx0, DQ_xxx0) across the waits.
;------------------------------------------------------------------------

;------------------------------------------------------------------------
; QINDEX - index into QDATA0 of a byte in a task's queue.
; In:   A = offset from the start of the task's buffer (masked to 0-15)
;       X = task ID
; Out:  X = index into QDATA0
; Uses: A X QTMP (callers hold FORBID, so QTMP is not shared)
;------------------------------------------------------------------------
QINDEX          AND #QSIZE-1
                STA QTMP
                TXA
                ASL
                ASL
                ASL
                ASL
                ORA QTMP
                TAX
                RTS

;------------------------------------------------------------------------
; ENQUEUE - write bytes to a task's queue, waiting for room as needed.
;       Writes what fits, sends the owner QUEUE_SIGNAL (rescheduling at
;       once if it is waiting, like SIGNAL), and if bytes are left,
;       waits for QSPACE_SIGNAL and writes some more. NQ_DONE0 counts
;       the bytes written so far. Stops early, without waiting, if the
;       queue is its own (nobody else would empty it) or the owner has
;       ended. Writers to the same queue can interleave between passes.
;       Not in the jump table yet. Used by USR(11).
; In:   INDEX1 ($22/$23) = address of the data
;       Y = length (0-255), X = task ID of the queue's owner
; Out:  Y = bytes written (Y on entry, unless it stopped early)
; Uses: A X Y
; Switches tasks: yes, when the queue is full, and when the owner was
;       waiting for bytes
; Note: ends with CLI
;------------------------------------------------------------------------
ENQUEUE         TYA
                LDY TID
                STA NQ_LEN0,Y
                TXA
                STA NQ_TO0,Y            ; readers now send us QSPACE_SIGNAL
                LDA INDEX1+0
                STA NQ_ADRL0,Y
                LDA INDEX1+1
                STA NQ_ADRH0,Y
                LDA #$00
                STA NQ_DONE0,Y

_loop           JSR FORBID              ; one writer at a time
                JSR NQ_FILL
                TAX                     ; X = bytes written this pass
                JSR PERMIT              ; (keeps X)
                TXA
                BEQ +                   ; none: no signal
                LDX TID
                LDY NQ_TO0,X
                LDA #QUEUE_SIGNAL
                JSR SIGNAL
+               LDX TID
                LDA NQ_DONE0,X
                CMP NQ_LEN0,X
                BEQ _done               ; all written
                LDA NQ_TO0,X            ; full: wait for room, unless
                CMP TID                 ; it's our own queue
                BEQ _done
                TAY
                LDA TASK_STATE0,Y       ; or its owner has ended
                BEQ _done
                LDA #QSPACE_SIGNAL
                JSR WAIT
                JMP _loop

_done           LDX TID
                SEI
                LDA #NO_TASK
                STA NQ_TO0,X
                LDA SIGNAL0,X           ; drop a QSPACE_SIGNAL left over
                AND #~QSPACE_SIGNAL
                STA SIGNAL0,X
                CLI
                LDY NQ_DONE0,X
                RTS

;------------------------------------------------------------------------
; NQ_FILL - ENQUEUE's inner part: copy as many of the running task's
;       remaining bytes as fit into the queue, and update NQ_DONE0.
; In:   NQ_xxx0 for the running task; FORBID held
; Out:  A = bytes written this pass
; Uses: A X Y INDEX1
;------------------------------------------------------------------------
NQ_FILL         LDX TID
                LDA NQ_TO0,X
                STA ENQUEUE_T
                LDA NQ_LEN0,X
                STA ENQUEUE_L
                LDA NQ_ADRL0,X
                STA INDEX1+0
                LDA NQ_ADRH0,X
                STA INDEX1+1
                LDY NQ_DONE0,X          ; Y = next byte to write
                STY ENQUEUE_S
-               CPY ENQUEUE_L
                BEQ _end                ; all written
                LDX ENQUEUE_T
                LDA QLEN0,X
                CMP #QSIZE
                BCS _end                ; queue full
                ADC QHEAD0,X            ; C clear: offset of the free byte
                JSR QINDEX
                LDA (INDEX1),Y
                STA QDATA0,X
                LDX ENQUEUE_T
                INC QLEN0,X
                INY
                BNE -                   ; always taken (Y stops at 255)
_end            TYA
                LDX TID
                STA NQ_DONE0,X
                SEC
                SBC ENQUEUE_S
                RTS

;------------------------------------------------------------------------
; DEQUEUE - read A bytes from the running task's own queue as a new
;       BASIC string. Takes what is there, and if it needs more, waits
;       for QUEUE_SIGNAL and takes some more. DQ_DONE0 counts the bytes
;       read so far. Each pass sends QSPACE_SIGNAL to the tasks writing
;       to the queue, rescheduling at once if one was waiting for room.
;       Used by USR(12).
; In:   A = bytes wanted (0-255; 0 returns an empty string at once)
; Out:  Y = bytes read (A on entry)
;       DSCTMP ($61-$63) = string descriptor (length, address)
; Uses: A X Y
; Switches tasks: yes, while the queue is empty, and when a writer was
;       waiting for room
; Note: ends with CLI
;------------------------------------------------------------------------
DEQUEUE         LDX TID
                STA DQ_LEN0,X
                JSR STRSPA              ; allocate the whole string now
                LDX TID
                LDA DSCTMP+1
                STA DQ_ADRL0,X
                LDA DSCTMP+2
                STA DQ_ADRH0,X
                LDA #$00
                STA DQ_DONE0,X

_loop           LDX TID
                LDA DQ_DONE0,X
                CMP DQ_LEN0,X
                BEQ _done               ; all read
                LDA QLEN0,X
                BNE _take
                LDA #QUEUE_SIGNAL       ; empty: wait for a writer. A stale
                JSR WAIT                ; signal just brings us back here
                JMP _loop

_take           JSR FORBID              ; DQ_TAKE's scratch is shared
                JSR DQ_TAKE
                JSR PERMIT
                SEI
                LDX TID
                JSR POST_WRITERS        ; tell writers there is room
                CLI
                BEQ _loop               ; none was waiting for it
                JSR UM_TS_PROC          ; let a waiting writer run
                JMP _loop

_done           LDA DQ_LEN0,X           ; the descriptor for PUTNEW
                STA DSCTMP+0
                TAY
                LDA DQ_ADRL0,X
                STA DSCTMP+1
                LDA DQ_ADRH0,X
                STA DSCTMP+2
                RTS

;------------------------------------------------------------------------
; DQ_TAKE - DEQUEUE's inner part: copy as many bytes as are waiting and
;       still wanted into the string, and update DQ_DONE0, QHEAD0,
;       QLEN0 and QUEUE_SIGNAL.
; In:   DQ_xxx0 for the running task; FORBID held
; Out:  -
; Uses: A X Y DSCTMP+1/+2 (as the string pointer)
; Note: ends with CLI
;------------------------------------------------------------------------
DQ_TAKE         LDX TID
                LDA DQ_ADRL0,X
                STA DSCTMP+1
                LDA DQ_ADRH0,X
                STA DSCTMP+2
                LDA DQ_LEN0,X
                SEC
                SBC DQ_DONE0,X          ; bytes still wanted
                CMP QLEN0,X
                BCC +
                LDA QLEN0,X             ; no more than are waiting
+               STA DEQUEUE_L
                LDY DQ_DONE0,X          ; Y = next byte of the string
                LDA #$00
                STA QCOUNT
-               LDA QCOUNT
                CMP DEQUEUE_L
                BEQ _copied
                LDX TID
                CLC
                ADC QHEAD0,X            ; offset of the next queued byte
                JSR QINDEX
                LDA QDATA0,X
                STA (DSCTMP+1),Y
                INY
                INC QCOUNT
                BNE -                   ; always taken (QCOUNT <= QSIZE)

_copied         LDX TID
                TYA
                STA DQ_DONE0,X
                SEI                     ; a writer pre-empting us must see
                LDA QHEAD0,X            ; QHEAD0 and QLEN0 change together
                CLC
                ADC DEQUEUE_L
                AND #QSIZE-1
                STA QHEAD0,X
                LDA QLEN0,X
                SEC
                SBC DEQUEUE_L
                STA QLEN0,X
                BEQ +
                LDA #QUEUE_SIGNAL       ; bytes left: keep the signal up
                ORA SIGNAL0,X
                BNE ++                  ; always taken
+               LDA #~QUEUE_SIGNAL      ; empty: clear it
                AND SIGNAL0,X
+               STA SIGNAL0,X
                CLI
                RTS

;------------------------------------------------------------------------
; POST_WRITERS - send QSPACE_SIGNAL to every task writing to a queue.
;       Used when the owner takes bytes out, and when it ends (writers
;       then see it has ended and give up).
; In:   X = task ID of the queue's owner; IRQs masked
; Out:  A = non-zero if one of them was waiting for it (Z clear)
; Uses: A QWOKE (X and Y kept)
;------------------------------------------------------------------------
POST_WRITERS    TYA
                PHA
                LDA #$00
                STA QWOKE
                LDY MAX_TASKS
                DEY
-               TXA
                CMP NQ_TO0,Y
                BNE +
                LDA #QSPACE_SIGNAL
                ORA SIGNAL0,Y
                STA SIGNAL0,Y
                AND WAIT0,Y
                ORA QWOKE
                STA QWOKE
+               DEY
                BPL -
                PLA
                TAY
                LDA QWOKE
                RTS

;------------------------------------------------------------------------
; NEW_TASK - common code for FORK and ADD_TASK.
;       Builds an interrupt frame that starts the new task at the given
;       address, finds a free task slot, and copies the running task's
;       memory into the new task's REU bank. Empties the new task's
;       queue.
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
                LDA #$00                ; empty queue
                STA QHEAD0,Y
                STA QLEN0,Y
                LDA #NO_TASK            ; not writing to a queue
                STA NQ_TO0,Y
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
                TYA
                TAX
                JSR POST_WRITERS        ; writers to its queue give up
                CLI
                JSR UM_TS_PROC          ; never comes back
