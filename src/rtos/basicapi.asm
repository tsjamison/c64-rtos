;========================================================================
; basicapi.asm - the BASIC API: USR(0) to USR(14)
;
; SYS 49152 points the USR() vector at USR_HANDLER. BASIC calls it with
; the USR number in FAC; USR_HANDLER dispatches through USRTBL. Handlers
; read any extra ",a,b" parameters themselves and return a byte result
; in Y through SNGFLT (or a string through PUTNEW).
;========================================================================

;------------------------------------------------------------------------
; BASIC work areas (names from "Mapping the Commodore 64")
;------------------------------------------------------------------------
POKER           = $14           ; 16-bit integer (address for PEEK/POKE/WAIT)
INDEX1          = $22           ; string pointer from LEN1
ANDMSK          = $49           ; BASIC WAIT: AND mask
EORMSK          = $4A           ; BASIC WAIT: EOR mask
DSCTMP          = $61           ; string descriptor from STRSPA (length, address)
FACMO           = $64           ; FAC1 middle-order byte (AYINT result hi)
FACLO           = $65           ; FAC1 low-order byte (AYINT result lo)
CHRGOT          = $79           ; re-read the current BASIC text character

;------------------------------------------------------------------------
; BASIC ROM routines
;------------------------------------------------------------------------
ERROR           = $A437         ; print BASIC error number X and stop
STROUT          = $AB1E         ; print zero-terminated string at A/Y (lo/hi)
FRMEVL          = $AD9E         ; evaluate any expression into FAC
CHKCOM          = $AEFD         ; check for a comma, else ?SYNTAX ERROR
AYINT           = $B1BF         ; FAC to signed 16-bit integer in FACMO/FACLO
FCERR           = $B248         ; ?ILLEGAL QUANTITY ERROR
SNGFLT          = $B3A2         ; return unsigned byte Y as the USR() result
GIVAYF          = $B391         ; return signed integer A (hi) Y (lo) as the result
STRSPA          = $B47D         ; allocate a string of length A, descriptor in DSCTMP
PUTNEW          = $B4CA         ; return the string in DSCTMP as the result
PREAM           = $B761         ; (not used)
LEN1            = $B782         ; string in FAC: length to Y, address to INDEX1
GETNUM          = $B7EB         ; read "address,byte": address to POKER, byte to X
COMBYT          = $B7F1         ; read ",byte" into X
GETADR          = $B7F7         ; FAC to unsigned 16-bit: Y = lo, A = hi, also POKER
LINPRT          = $BDCD         ; print unsigned 16-bit number, A = hi, X = lo
FOUT            = $BDDD         ; (not used)


;------------------------------------------------------------------------
; USR() dispatch table: handler address-1, for an RTS jump
;------------------------------------------------------------------------
USRTBL          .word USR_GETTID-1      ; USR(0)
                .word USR_FORK-1        ; USR(1)
                .word USR_FORBID-1      ; USR(2)
                .word USR_PERMIT-1      ; USR(3)
                .word USR_REMTASK-1     ; USR(4)[,TASK]
                .word USR_SETPRI-1      ; USR(5),TASK,PRI
                .word USR_SETCOOP-1     ; USR(6),TASK,COOP
                .word USR_WAIT-1        ; USR(7),MASK
                .word USR_SIGNAL-1      ; USR(8),TASK,SIG_SET
                .word USR_SLEEP-1       ; USR(9),JIFFIES
                .word USR_WAITM-1       ; USR(10)ADDR,AND[,EOR]
                .word USR_NQ-1          ; USR(11)STR,TASK
                .word USR_DQ-1          ; USR(12)
                .word USR_MAXTASKS-1    ; USR(13)
                .word USR_STATE-1       ; USR(14),TASK
USRTBL_END

;------------------------------------------------------------------------
; USR_HANDLER - USR() entry point. Range-checks the USR number and
;       jumps to its handler.
; In:   FAC = USR number
; Errors: ?ILLEGAL QUANTITY ERROR if it is not in USRTBL
;------------------------------------------------------------------------
USR_HANDLER     JSR AYINT
                LDA FACMO
                BNE +                   ; 256 or more (or negative)
                LDA FACLO
                CMP #(USRTBL_END-USRTBL)/2
                BCC ++
+               JMP FCERR               ; ?ILLEGAL QUANTITY ERROR
+               ASL
                TAY
                LDA USRTBL+1,Y
                PHA
                LDA USRTBL+0,Y
                PHA
                RTS


;------------------------------------------------------------------------
; USR(1) - FORK. Returns the new task's ID to the parent, and 255 to
;       the new task (like fork(), which returns 0 to the child: 0 is a
;       valid task ID here). The child starts with the parent's priority and
;       co-op, FORBID level 0, and no sleep timer, signals or wait.
;       Sharing the parent's co-op, it can't run until the parent
;       waits or yields, or moves it to another co-op with USR(6).
; Errors: ?OUT OF MEMORY ERROR if every task slot is in use
; Switches tasks: no (the child runs when the scheduler picks it)
;------------------------------------------------------------------------
USR_FORK
; Save the stack pointer
                SEI
                TSX
                TXA
                LDY TID
                STA SP0,Y

; Push a fake interrupt frame that starts the child at _forked
                LDA #>_forked
                PHA
                LDA #<_forked
                PHA
                LDA #FAKE_P
                PHA
                LDA #$00                ; A, X, Y
                PHA
                PHA
                PHA

; Find the next empty slot
                LDX TID
-               INX
                CPX MAX_TASKS
                BNE +
                LDX #$00
+               CPX TID
                BNE +
                LDX #ERR_OUT_OF_MEMORY  ; every slot is in use
                JMP ERROR
+               LDA TASK_STATE0,X
                BNE -
                STX NTID
                LDA #TS_READY
                STA TASK_STATE0,X

; Start the new task clean: no sleep timer, signals, wait mask or queue left
; over from the slot's last task, and the parent's priority and co-op.
; Interrupts are still off, so INT can't post to the slot meanwhile.
                LDA #$00
                STA SLEEP0,X
                STA SLEEP1,X
                STA SIGNAL0,X
                STA WAIT0,X
                STA QHEAD0,X            ; and an empty queue
                STA QLEN0,X
                LDA #NO_TASK            ; not writing to a queue
                STA NQ_TO0,X
                LDY TID
                LDA PRI0,Y
                STA PRI0,X
                LDA COOP0,Y
                STA COOP0,X
                LDA #$01                ; FORBID count 0, plus the 1 the scheduler's
                STA FORBID0,X           ; PERMIT takes off when it first runs the task

; Duplicate the current task's memory for the new task
                LDA #<_copied
                STA XFER_RET
                LDA #>_copied
                STA XFER_RET+1
                LDY #XFER_SAVE
                JMP XFER_BASIC_XY

_copied         LDY NTID
                TSX
                TXA
                STA SP0,Y

                LDY TID
                LDX SP0,Y
                TXS
                LDY NTID                ; parent gets the new task's ID. Read
                CLI                     ; before CLI: the scheduler uses NTID
                JMP SNGFLT

; The new task starts here, from the frame pushed above
_forked         LDY #NO_TASK            ; new task gets 255
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(0) - return the running task's ID
;------------------------------------------------------------------------
USR_GETTID      LDY TID
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(2) - FORBID. Returns the new FORBID level.
;------------------------------------------------------------------------
USR_FORBID      JSR FORBID
                LDY TS_ENABLE
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(3) - PERMIT. Returns the new FORBID level (0 = switching allowed).
;------------------------------------------------------------------------
USR_PERMIT      JSR PERMIT
                LDY TS_ENABLE
                JMP SNGFLT

;------------------------------------------------------------------------
; GETTASK - read ",task" into X and check it is a task ID (below
;       MAX_TASKS), so a bad ID can't write past the per-task arrays.
; Out:  X = task ID
; Uses: A X
; Errors: ?ILLEGAL QUANTITY ERROR
;------------------------------------------------------------------------
GETTASK         JSR COMBYT
                CPX MAX_TASKS
                BCC +
                JMP FCERR
+               RTS

;------------------------------------------------------------------------
; USR(13) - return the number of tasks available
;------------------------------------------------------------------------
USR_MAXTASKS    LDY MAX_TASKS
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(14),TASK - return the task's state (TS_xxx)
;------------------------------------------------------------------------
USR_STATE       JSR GETTASK
                JSR GET_STATE
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(5),TASK,PRI - set the task's priority. Returns the old priority.
;------------------------------------------------------------------------
USR_SETPRI      JSR GETTASK
                JSR GET_PRI             ; Y = old priority
                TYA
                PHA
                TXA                     ; task ID
                PHA
                JSR COMBYT              ; X = new priority
                PLA
                TAY                     ; Y = task ID
                TXA                     ; A = new priority
                JSR SET_PRI
                PLA
                TAY                     ; Y = old priority
                JMP SNGFLT

;------------------------------------------------------------------------
; USR_GETPRI - not reachable: not in USRTBL
;------------------------------------------------------------------------
USR_GETPRI      JSR GETTASK
                JSR GET_PRI             ; Y = priority of task X
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(6),TASK,COOP - move the task to a co-op (0-15). Returns the old
;       co-op.
; Errors: ?ILLEGAL QUANTITY ERROR for a co-op above 15
;------------------------------------------------------------------------
USR_SETCOOP     JSR GETTASK
                JSR GET_COOP            ; Y = old co-op
                TYA
                PHA
                TXA                     ; task ID
                PHA
                JSR COMBYT              ; X = new co-op
                CPX #MXCOOPS
                BCC +
                JMP FCERR               ; ?ILLEGAL QUANTITY: co-ops are 0-15
+               PLA
                TAY                     ; Y = task ID
                TXA                     ; A = new co-op
                JSR SET_COOP
                PLA
                TAY                     ; Y = old co-op
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(7),MASK - wait for any signal in MASK. Always passes through the
;       scheduler, so it is a yield point even if a signal is already
;       there. Returns the signals in MASK that woke the task.
;       Signals: $80 free, $40 timer, $20 memory, $10 queue,
;       $01, $02, $04 and $08 for applications.
; Switches tasks: yes
;------------------------------------------------------------------------
USR_WAIT        JSR COMBYT
                TXA
                JSR WAIT
                TAY
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(8),TASK,SIG_SET - post signals to a task. If it was waiting for
;       one of them, the scheduler runs at once. Returns the task's
;       signal set when SIGNAL returns: if the task has run by then, it
;       has already cleared the signals that woke it.
; Switches tasks: yes, if the task was waiting for one of the signals
;------------------------------------------------------------------------
USR_SIGNAL      JSR GETTASK
                TXA
                PHA
                JSR COMBYT              ; X = signals
                PLA
                TAY                     ; Y = task ID
                TXA
                JSR SIGNAL
                TAY
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(9),JIFFIES - sleep for 0-65535 jiffies. Returns the signals that
;       woke the task.
; Switches tasks: yes
;------------------------------------------------------------------------
USR_SLEEP       JSR CHKCOM
                JSR FRMEVL
                JSR GETADR              ; Y = lo, A = hi
                JSR SLEEP
                TAY
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(10)ADDR,AND[,EOR] - wait until (PEEK(ADDR) EOR EOR) AND AND is
;       non-zero. Returns that value. Duplicates WAIT_MEMORY.
; Switches tasks: yes
;------------------------------------------------------------------------
USR_WAITM       JSR GETNUM              ; POKER = address, X = AND mask
                LDY TID
                TXA
                STA ANDMSK0,Y
                LDX #$00                ; EOR mask defaults to 0
                JSR CHRGOT
                BEQ +
                JSR COMBYT              ; X = EOR mask
+               LDY TID
                TXA
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
                JMP SNGFLT

;------------------------------------------------------------------------
; USR(11)STR,TASK - send STR to TASK's queue as one message. Any task
;       can send to any task. Waits until the queue has room for it.
;       TASK gets QUEUE_SIGNAL, and runs at once if it was waiting and
;       its priority allows. STR "" sends an empty message.
;       Returns LEN(STR), or -1 if it was not sent: TASK is the running
;       task and its own queue lacks room, or TASK ended while we waited.
; Errors: ?ILLEGAL QUANTITY ERROR if LEN(STR) is over 15
; Switches tasks: yes, while the queue lacks room, or when TASK was
;       waiting
;------------------------------------------------------------------------
USR_NQ          JSR FRMEVL
                JSR LEN1                ; Y = length, INDEX1 = address
                CPY #QMSGMAX+1
                BCC +
                JMP FCERR               ; messages are 0-15 bytes

+               TYA                     ; keep them on our stack: GETTASK's
                PHA                     ; expression evaluation can change
                LDA INDEX1+1            ; INDEX1, and another task can run
                PHA
                LDA INDEX1+0
                PHA

                JSR GETTASK             ; X = task whose queue gets STR

                PLA
                STA INDEX1+0
                PLA
                STA INDEX1+1
                PLA
                TAY
                JSR ENQUEUE
                LDA #$00
                BCC +
                LDA #$FF                ; not sent: -1
                TAY
+               JMP GIVAYF              ; A/Y = length, or -1

;------------------------------------------------------------------------
; USR(12) - receive the next message from the running task's own
;       queue as a string, waiting until there is one. An empty
;       message returns "". (With timeouts, a timeout will return ""
;       too.)
; Switches tasks: yes, while the queue is empty, and when a writer was
;       waiting for room
;------------------------------------------------------------------------
USR_DQ          JSR DQ_WAIT             ; A = message length
                JSR STRSPA              ; string of exactly that length
                LDA DSCTMP+1            ; only we read our queue, so the
                STA INDEX1+0            ; message is still the next one
                LDA DSCTMP+2
                STA INDEX1+1
                JSR DQ_COPY
                ; Drop USR()'s own return address from the stack: it
                ; checks for a numeric result (?TYPE MISMATCH ERROR)
                PLA
                PLA
                JMP PUTNEW              ; return the new string

;------------------------------------------------------------------------
; USR(4)[,TASK] - end TASK, or the running task if no TASK is given.
;       Returns 0 (when it returns at all).
; Switches tasks: yes
;------------------------------------------------------------------------
USR_REMTASK     LDX TID
                JSR CHRGOT
                BEQ +                   ; no ",TASK": end ourselves
                JSR GETTASK
+               TXA
                TAY
                SEI
                JSR COOP_RELEASE        ; free its co-op so its other tasks can run
                LDA #TS_INVALID
                STA TASK_STATE0,Y
                TYA
                TAX
                JSR POST_WRITERS        ; writers to its queue give up
                CLI
                JSR UM_TS_PROC          ; never comes back if the task ended itself
                LDY #$00
                JMP SNGFLT
