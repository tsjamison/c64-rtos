;========================================================================
; C64 RTOS - multitasking for the Commodore 64
;
; Main source file. The other source files are included near the end.
; Build:    64tass -o ../../release/rtos rtos.asm
; Listing:  add  -l rtos.txt  (labels) or  -L rtos.lst  (full listing)
;
; Conventions used in these sources:
;   - Labels start in column 1, instructions in column 17.
;   - Constants and global labels are UPPER_CASE. Labels starting with
;     _ are local to the routine above them. Anonymous labels (+ and -)
;     are only used for jumps of a few lines.
;   - Each routine has a header listing its inputs, outputs, the
;     registers it changes, and whether it can switch tasks.
;========================================================================

;------------------------------------------------------------------------
; KERNAL and BASIC work areas (names from "Mapping the Commodore 64")
;------------------------------------------------------------------------
USRADD          = $0311         ; USR() function vector
CINV            = $0314         ; IRQ vector
VARTAB          = $2D           ; start of BASIC variables
STREND          = $31           ; end of BASIC arrays
FRETOP          = $33           ; bottom of BASIC string storage
MEMSIZ          = $37           ; top of BASIC memory
STACK           = $0100         ; 6502 stack page

;------------------------------------------------------------------------
; Hardware registers
;------------------------------------------------------------------------
VIC_BORDER      = $D020         ; border colour
VIC_BKGND       = $D021         ; background colour

;------------------------------------------------------------------------
; RTOS limits
;------------------------------------------------------------------------
MXTASKS         = 16            ; most tasks supported (one REU bank each)
MXCOOPS         = 16            ; co-ops 0-15, one owner byte each
QSIZE           = 16            ; bytes in each task's queue
QMSGMAX         = QSIZE-1       ; longest message: a length byte + 15 bytes

                .cerror MXCOOPS & (MXCOOPS-1), "MXCOOPS must be a power of two (SET_COOP masks with it)"
                .cerror QSIZE != 16, "QINDEX shifts the task ID left 4 times"
                .cerror MXTASKS*QSIZE > 256, "QDATA0 is indexed with X"

; Task states
TS_INVALID      = 0
TS_ADDED        = 1             ; defined but not used yet
TS_RUN          = 2
TS_READY        = 3
TS_WAIT         = 4
TS_EXCEPT       = 5             ; defined but not used yet
TS_REMOVED      = 6             ; defined but not used yet
TS_COOPTED      = 7             ; not stored: GET_STATE works these two out
TS_PREEMPT      = 8             ; from COOP_OWNER for USR(14)

; Signal masks. $80 is free; $01, $02, $04 and $08 are for
; applications.
TIMER_SIGNAL    = $40
WAITM_SIGNAL    = $20
QUEUE_SIGNAL    = $10

; Status byte for the fake interrupt frames pushed to start a task
; switch: only the always-set bit 5, so I is clear and RTI re-enables IRQs.
FAKE_P          = $20

; BASIC error number passed to ERROR in X
ERR_OUT_OF_MEMORY = 16

COOP_FREE       = $FF           ; COOP_OWNER value for a co-op nobody holds
NO_TASK         = $FF           ; NTID value when the scheduler found no task

                .include "jumptable.inc"


                .cpu "6502"
                * = $C000       ; RTOS code and data, loaded with SYS 49152

;------------------------------------------------------------------------
; Jump table. Addresses are defined in jumptable.inc; each .cerror makes
; the build fail if an entry moves.
;------------------------------------------------------------------------
                .cerror * != RTOS_INIT, "jump table moved: RTOS_INIT"
                JMP INITIALIZE
                .cerror * != RTOS_FORBID, "jump table moved: RTOS_FORBID"
                JMP FORBID
                .cerror * != RTOS_PERMIT, "jump table moved: RTOS_PERMIT"
                JMP PERMIT
                .cerror * != RTOS_FORK, "jump table moved: RTOS_FORK"
                JMP FORK
                .cerror * != RTOS_ADDTASK, "jump table moved: RTOS_ADDTASK"
                JMP ADD_TASK
                .cerror * != RTOS_ENDTASK, "jump table moved: RTOS_ENDTASK"
                JMP END_TASK
                .cerror * != RTOS_SETPRI, "jump table moved: RTOS_SETPRI"
                JMP SET_PRI
                .cerror * != RTOS_GETPRI, "jump table moved: RTOS_GETPRI"
                JMP GET_PRI
                .cerror * != RTOS_SETCOOP, "jump table moved: RTOS_SETCOOP"
                JMP SET_COOP
                .cerror * != RTOS_GETCOOP, "jump table moved: RTOS_GETCOOP"
                JMP GET_COOP
                .cerror * != RTOS_WAIT, "jump table moved: RTOS_WAIT"
                JMP WAIT
                .cerror * != RTOS_SIGNAL, "jump table moved: RTOS_SIGNAL"
                JMP SIGNAL
                .cerror * != RTOS_SLEEP, "jump table moved: RTOS_SLEEP"
                JMP SLEEP
                .cerror * != RTOS_WAITMEM, "jump table moved: RTOS_WAITMEM"
                JMP WAIT_MEMORY
; Planned:      ENQUEUE, DEQUEUE


;------------------------------------------------------------------------
; INITIALIZE - print the banner, size the REU, hook the IRQ and USR()
;              vectors and reset all task tables. Holds FORBID
;              throughout, so no task switch can land in the middle.
;              Running it again does not hook the IRQ twice or size the
;              REU again (it reuses SIZEL/SIZEH), but it forgets every
;              task: the caller carries on as task 0, at priority 0,
;              co-op 0 and FORBID level 0.
; In:   -
; Out:  -       (returns early, not installed, if no REU is found)
; Uses: A X Y
;------------------------------------------------------------------------
INITIALIZE      LDA #1
                STA TS_ENABLE           ; FORBID, also valid on a first run
                LDA #<VERSION
                LDY #>VERSION
                JSR STROUT

; Installed already? Checked once, here: if the IRQ vector points at
; INT, this is a second run. Then SIZEL/SIZEH still hold the REU size,
; and the IRQ must not be hooked again.
                SEI
                LDA CINV
                CMP #<INT
                BNE _install
                LDA CINV+1
                CMP #>INT
                BEQ _installed

_install        JSR REU_SIZE            ; X/A = number of 64KB banks
                STX SIZEL
                STA SIZEH

                ORA SIZEL
                BNE +
                LDA #<REU_REQ
                LDY #>REU_REQ
                JMP STROUT

+               LDA CINV
                STA OLD_IRQ
                LDA CINV+1
                STA OLD_IRQ+1

                LDA #<INT
                STA CINV
                LDA #>INT
                STA CINV+1

_installed
                LDX SIZEL
                BNE +
                LDX #$FF                ; 256 or more banks
+               CPX #MXTASKS
                BCC +
                LDX #MXTASKS
+               STX MAX_TASKS


; Reset variables
                LDA #$00
                STA VIC_BORDER          ; border = task 0's colour
                STA TID                 ; task 0 is running
                LDY MAX_TASKS
                DEY
-               STA TASK_STATE0,Y       ; TS_INVALID
                STA PRI0,Y
                STA COOP0,Y
                STA WAIT0,Y
                STA SIGNAL0,Y
                STA SLEEP0,Y
                STA SLEEP1,Y
                STA FORBID0,Y
                STA QHEAD0,Y
                STA QLEN0,Y
                DEY
                BPL -
                LDA #TS_RUN
                STA TASK_STATE0
                LDX #MXTASKS-1          ; no task is writing to a queue
                LDA #NO_TASK
-               STA NQ_TO0,X
                DEX
                BPL -

; All co-ops free, except co-op 0, held by running task 0
                LDX #MXCOOPS-1
                LDA #COOP_FREE
-               STA COOP_OWNER,X
                DEX
                BPL -
                LDA #$00
                STA COOP_OWNER

; Point USR() at our dispatcher
                LDA #<USR_HANDLER
                STA USRADD
                LDA #>USR_HANDLER
                STA USRADD+1

                LDA #$00
                STA TS_ENABLE           ; task switching allowed

                CLI

; Print REU size and max tasks
                LDA #<REU_BANKS
                LDY #>REU_BANKS
                JSR STROUT

                LDA SIZEH
                LDX SIZEL
                JSR LINPRT

                LDA #<MAXTASK
                LDY #>MAXTASK
                JSR STROUT

                LDA #$00
                LDX MAX_TASKS
                JSR LINPRT

                LDA #<RTOS_INSTALLED
                LDY #>RTOS_INSTALLED
                JSR STROUT

                RTS


;------------------------------------------------------------------------
; INT - IRQ handler, installed in CINV. Runs on every IRQ: normally
;       just the KERNAL's jiffy timer (60 a second), but any IRQ a
;       program adds (raster, CIA) also runs it, which shortens sleeps
;       and pre-empts more often.
;       Counts down sleep timers and tests WAITM addresses, posting
;       TIMER_SIGNAL / WAITM_SIGNAL to tasks whose condition is met.
;       Then, unless task switching is forbidden, pushes a fake
;       interrupt frame so the KERNAL's RTI drops into UM_TS.
;       Exits through the previous IRQ handler (OLD_IRQ).
; In:   KERNAL IRQ entry (A X Y already saved on the stack)
; Uses: A X Y   (restored by the KERNAL's exit code)
;------------------------------------------------------------------------
INT
; @todo Before checking if TS is Permitted:
; @todo Update Timer / Input Devices
; @todo Update Quantum

; Save POKER in INT-only scratch bytes. XFER_RET holds the
; XFER_BASIC_XY return address and must not be touched here.
                LDA POKER+0
                STA INT_POKER
                LDA POKER+1
                STA INT_POKER+1

                LDX MAX_TASKS
                DEX
_task_loop
; If the SLEEP counter is 0, skip the timer
                LDA SLEEP0,X
                ORA SLEEP1,X
                BEQ _check_waitm

; Decrement the SLEEP counter
                LDA SLEEP0,X
                BNE +
                DEC SLEEP1,X
+               DEC SLEEP0,X

; If the SLEEP counter is still running, skip
                LDA SLEEP1,X
                ORA SLEEP0,X
                BNE _check_waitm

; SIGNAL task, because SLEEP timer just elapsed
                LDA #TIMER_SIGNAL
                ORA SIGNAL0,X
                STA SIGNAL0,X

; Is the task waiting on memory (WAITM)?
_check_waitm    LDA WAIT0,X
                AND #WAITM_SIGNAL
                BEQ _next_task

; Test memory: (address EOR EORMSK) AND ANDMSK non-zero = done
                TXA
                ASL
                TAY
                LDA POKER0+0,Y
                STA POKER+0
                LDA POKER0+1,Y
                STA POKER+1
                LDY #$00
                LDA (POKER),Y
                EOR EORMSK0,X
                AND ANDMSK0,X
                BEQ _next_task
                STA WAITM0,X            ; result for WAIT_MEMORY / USR(10)

; Wait done, signal task
                LDA #WAITM_SIGNAL
                ORA SIGNAL0,X
                STA SIGNAL0,X

_next_task      DEX
                BPL _task_loop

                LDA INT_POKER
                STA POKER+0
                LDA INT_POKER+1
                STA POKER+1

                LDA TS_ENABLE           ; 0 means task switching enabled
                BNE _chain

; Push a fake interrupt frame (PC hi, PC lo, P, A, X, Y) that returns
; into UM_TS, the scheduler, when the KERNAL exits with RTI
                LDA #>UM_TS
                PHA
                LDA #<UM_TS
                PHA
                LDA #FAKE_P
                PHA
                LDA #$00
                PHA
                PHA
                PHA

_chain          JMP (OLD_IRQ)


                .include "um-ts.asm"
                .include "api.asm"
                .include "basicapi.asm"
                .include "reu.asm"


;------------------------------------------------------------------------
; Strings
;------------------------------------------------------------------------
VERSION         .null "C64 RTOS V0.9 COPYRIGHT 2026 TIM JAMISON"
REU_REQ         .null "REU REQUIRED. RTOS NOT INSTALLED.", 13
REU_BANKS       .null "REU BANKS FOUND: "
MAXTASK         .null 13, "TASKS AVAILABLE: "
RTOS_INSTALLED  .null 13, "RTOS INSTALLED.", 13

;------------------------------------------------------------------------
; Variables. Arrays ending in 0 have one entry per task, indexed by
; task ID. All of this is shared: none of it is in the task memory
; swapped to the REU. (UM_TS saves TS_ENABLE in FORBID0 itself.)
;------------------------------------------------------------------------
TS_ENABLE       .byte ?         ; FORBID level of the running task, 0 = switching allowed
MAX_TASKS       .byte ?         ; tasks available (REU banks, at most MXTASKS)
SP0             .fill MXTASKS   ; saved stack pointer
TASK_STATE0     .fill MXTASKS   ; TS_xxx
PRI0            .fill MXTASKS   ; priority, higher runs first
COOP0           .fill MXTASKS   ; co-op number, 0-15
WAIT0           .fill MXTASKS   ; signals the task is waiting for, 0 = none
SIGNAL0         .fill MXTASKS   ; signals received
SLEEP0          .fill MXTASKS   ; sleep timer in jiffies, lo
SLEEP1          .fill MXTASKS   ; sleep timer in jiffies, hi
POKER0          .fill MXTASKS*2 ; WAITM address, 16 bits per task
EORMSK0         .fill MXTASKS   ; WAITM EOR mask
ANDMSK0         .fill MXTASKS   ; WAITM AND mask
WAITM0          .fill MXTASKS   ; WAITM result
FORBID0         .fill MXTASKS   ; saved TS_ENABLE (FORBID level)

TID             .byte ?         ; running task
NTID            .byte ?         ; next task (scheduler, FORK)
MXPRI           .byte ?         ; scheduler: best priority found so far

QHEAD0          .fill MXTASKS   ; queue: offset of the next byte to read, 0-15
QLEN0           .fill MXTASKS   ; queue: bytes waiting, 0-16
NQ_TO0          .fill MXTASKS   ; ENQUEUE: queue being written to, NO_TASK = none
NQ_LEN0         .fill MXTASKS   ; ENQUEUE: message length
NQ_ADRL0        .fill MXTASKS   ; ENQUEUE: address of the message, lo
NQ_ADRH0        .fill MXTASKS   ;   and hi

OLD_IRQ         .word ?         ; previous IRQ handler, INT chains to it

; SCRATCH - shared scratch word. Only for code that holds FORBID (or
; runs with IRQs masked) and doesn't switch tasks while it needs the
; value. INT must not use it.
; Used by: INITIALIZE (REU size), NEW_TASK (start address),
;          NQ_WRITE and DQ_COPY (queue buffer offset)
SCRATCH         .word ?
FORK_FLAG       .byte ?         ; NEW_TASK: non-zero = FORK, 0 = ADD_TASK
ENQUEUE_L       .byte ?         ; NQ_WRITE scratch: length,
ENQUEUE_T       .byte ?         ;   queue owner (FORBID held)
DEQUEUE_L       .byte ?         ; DQ_COPY scratch: length (FORBID held)
QWOKE           .byte ?         ; POST_WRITERS scratch (IRQs masked)
COOP_OWNER      .fill MXCOOPS   ; task holding each co-op, COOP_FREE = free

XFER_RET        .word ?         ; where XFER_BASIC_XY returns to
INT_POKER       .word ?         ; INT scratch: saved POKER

QDATA0          .fill MXTASKS*QSIZE ; queue data, QSIZE bytes per task
REU_TEMP        .fill 257       ; REU_SIZE: probe byte + one saved byte per bank
REU_LAST        .byte ?         ; REU_SIZE: last bank number read back
SIZEL           .byte ?         ; REU_SIZE: banks found, lo (INITIALIZE
SIZEH           .byte ?         ;   reuses them on a second run), hi

                .cerror * > $D000, "RTOS overlaps the I/O area at $D000"
