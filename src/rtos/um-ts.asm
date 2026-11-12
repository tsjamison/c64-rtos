;========================================================================
; um-ts.asm - the scheduler (UM_TS) and its entry from task code
;========================================================================

;------------------------------------------------------------------------
; UM_TS_PROC - yield to the scheduler from task code (call with JSR).
;       Turns the JSR return address into an interrupt frame (PC, P,
;       A, X, Y), then enters UM_TS. Returns, possibly much later,
;       once the scheduler picks this task again.
; In:   -
; Out:  A preserved, X = Y = A
; Uses: X Y, N Z
; Switches tasks: yes
;------------------------------------------------------------------------
UM_TS_PROC      TSX
                INC STACK+1,X           ; JSR pushed address-1, RTI wants
                BNE +                   ; the address itself, so add 1
                INC STACK+2,X
+               PHP
                PHA                     ; fake A, X, Y
                PHA
                PHA
                JMP UM_TS

; Background: how the 6502 and KERNAL enter an interrupt
;   CPU pushes PC hi, PC lo, P, then JMP ($FFFE) -> $FF48
;   KERNAL pushes A, X, Y and checks the B flag in the saved P:
;   JMP ($0316) if set (BRK instruction), JMP ($0314) if clear (IRQ)

; @todo - Decide if/how to utilise BRK

;------------------------------------------------------------------------
; UM_TS - the scheduler. Entered with an interrupt frame on the stack:
;       from INT once a jiffy while the running task's FORBID level is 0
;       (pre-emption), or from UM_TS_PROC when a task waits, yields,
;       signals another task or ends.
;
;       1. Wake: each WAIT task that has a signal it waits for becomes
;          READY. (INT posts the timer and WAITM signals.)
;
;       2. Pick the next task. A task is a candidate only if its co-op
;          lets it run: the co-op is free, or the task already holds it
;          (COOP_OK). The highest-priority candidate wins.
;          - If the current task is still RUN, it is the first
;            candidate and the scan starts below it. If it waited,
;            yielded or ended, it is not RUN: the scan starts with it,
;            and it counts only if it is READY again.
;          - The scan goes down from there, wrapping from 0 to
;            MAX_TASKS-1, and stops when it gets back to TID, so the
;            last task looked at is TID+1. Each READY candidate whose
;            priority is >= the best so far replaces it, so on a tie
;            the task scanned last wins: the next one above TID.
;          - So tasks of equal priority in different co-ops take turns
;            in ascending order, one per jiffy (round robin), and the
;            running task gives way to any of them. It keeps the CPU
;            only while every other candidate has a lower priority.
;            A lower-priority task runs only when no higher one can.
;
;       3. No candidate: cycle the border colour and go back to 1.
;          Interrupts stay on, so INT keeps counting sleeps and checking
;          WAITMs, and a task wakes as soon as its signal arrives.
;
;       4. Otherwise the running task, if pre-empted, goes back to
;          READY but keeps its co-op, and the chosen task becomes RUN
;          and takes its co-op. If it is a different task, this task's
;          stack pointer and FORBID level are saved, its memory goes to
;          its REU bank, and the new task's memory, stack pointer and
;          FORBID level are loaded. The border shows the task's colour,
;          and RTI resumes it from the frame on its stack.
; In:   interrupt frame on the stack (PC, P, A, X, Y)
; Out:  RTI to the chosen task
; Switches tasks: yes
;------------------------------------------------------------------------
UM_TS
                JSR FORBID

_loop           LDA #NO_TASK
                STA NTID
                LDA #$00
                STA MXPRI

; Check WAITing tasks to see if they received a signal for what they
; were WAITing for. A woken task is READY; COOP_OK decides below
; whether its co-op lets it run.
                LDY MAX_TASKS
-               DEY
                BMI _current
                LDA TASK_STATE0,Y
                CMP #TS_WAIT
                BNE -
                LDA WAIT0,Y
                AND SIGNAL0,Y
                BEQ -
                LDA #TS_READY
                STA TASK_STATE0,Y
                BNE -                   ; always taken

; If the current task is running and its co-op still lets it run, it
; is the candidate to beat, and the scan starts below it. Otherwise
; the scan starts with the current task itself (READY after a yield
; or wake-up, or not a candidate at all)
_current        LDY TID
                LDA TASK_STATE0,Y
                CMP #TS_RUN
                BNE _scan
                JSR COOP_OK
                BCS _scan               ; moved into a co-op another task holds
                STY NTID
                LDA PRI0,Y
                STA MXPRI
                JMP _next

; Scan down from Y, wrapping, until back at TID (so TID+1 is last),
; for the highest-priority READY task that its co-op allows
_scan           LDA TASK_STATE0,Y
                CMP #TS_READY
                BNE _next
                LDA PRI0,Y
                CMP MXPRI
                BCC _next               ; skip if PRI0,Y < MXPRI
                JSR COOP_OK
                BCS _next               ; another task holds its co-op

; PRI0,Y >= MXPRI: best candidate so far. On a tie the task scanned
; later wins, which gives round robin among equal priorities
                STY NTID
                LDA PRI0,Y
                STA MXPRI

_next           DEY
                BPL +
                LDY MAX_TASKS
                DEY
+               CPY TID
                BNE _scan

                LDA NTID
                CMP #NO_TASK
                BNE _found

; No task selected to run: cycle the border colour on every pass, so
; idle time shows as stripes in the border (task colours are solid)
                INC VIC_BORDER
                JMP _loop

; Update the task states of the running task and the new one.
; A pre-empted task goes back to READY but keeps its co-op.
_found          LDA TASK_STATE0,Y
                CMP #TS_RUN
                BNE +
                LDA #TS_READY
                STA TASK_STATE0,Y
+               LDY NTID
                LDA #TS_RUN
                STA TASK_STATE0,Y
                LDX COOP0,Y             ; new task takes its co-op
                TYA
                STA COOP_OWNER,X

                LDY TID
                CPY NTID
                BEQ TS_SWAP_END         ; same task: no swap needed

; Swap tasks: save this task's stack pointer and FORBID level...
                TSX
                TXA
                STA SP0,Y
                LDA TS_ENABLE           ; each task keeps its own FORBID count
                STA FORBID0,Y           ; (plus the 1 UM_TS added on entry)

; ...save its memory to its REU bank...
                LDA #<_saved
                STA XFER_RET
                LDA #>_saved
                STA XFER_RET+1
                LDY #XFER_SAVE
                LDX TID
                SEI
                JMP XFER_BASIC_XY

; ...and load the new task's memory from its bank
_saved          LDA #<_loaded
                STA XFER_RET
                LDA #>_loaded
                STA XFER_RET+1

                LDY #XFER_LOAD
                LDX NTID
                STX TID
                JMP XFER_BASIC_XY

; Now on the new task's stack
_loaded         LDY TID
                LDX SP0,Y
                TXS
                LDA FORBID0,Y           ; new task gets its own count back;
                STA TS_ENABLE           ; PERMIT below takes off UM_TS's 1

TS_SWAP_END     STY VIC_BORDER          ; border = running task's colour

                JSR PERMIT
                CLI

                PLA
                TAY
                PLA
                TAX
                PLA
                RTI

;------------------------------------------------------------------------
; COOP_OK - can task Y run as far as its co-op is concerned?
; In:   Y = task ID
; Out:  C clear = yes: the co-op is free, or Y already holds it
;       C set   = no: another task holds it
; Uses: A X
;------------------------------------------------------------------------
COOP_OK         LDX COOP0,Y
                LDA COOP_OWNER,X
                BMI +                   ; COOP_FREE: co-op is free
                TYA
                CMP COOP_OWNER,X
                BNE ++                  ; another task holds it
+               CLC
                RTS
+               SEC
                RTS

;------------------------------------------------------------------------
; COOP_RELEASE - task Y gives up its co-op, if it holds it.
; In:   Y = task ID
; Out:  -
; Uses: A X
;------------------------------------------------------------------------
COOP_RELEASE    LDX COOP0,Y
                TYA
                CMP COOP_OWNER,X
                BNE +
                LDA #COOP_FREE
                STA COOP_OWNER,X
+               RTS
