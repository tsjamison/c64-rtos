POKER     = $14
ANDMSK    = $49
EORMSK    = $4A
CHRGOT    = $79
ERROR     = $A437
evalparam = $AD9E
skipcomma = $AEFD
AYINT     = $B1BF
FCERR     = $B248
SNGFLT    = $B3A2
GETNUM    = $B7EB
convert16 = $B7F7
FOUT      = $BDDD

; USR(.)[,...]
; 0   GET PID
; 1   Fork
; 2   Forbid
; 3   Permit
; 4   RemTask(task)
; 5   SetTaskPri <PID>,<PRI>
; 6   GetTaskPri <PID> PID of -1 is own PID
; 7   Wait(signalSet), signalSet of 0 is YIELD
; 8   Signal(task, signalSet)
; 9   Sleep(jiffies)
; 10  Joystick(port 1 and/or 2)

USRTBL		.word USR_GETTID-1  ;USR(0)
			.word USR_FORK-1    ;USR(1)
			.word USR_FORBID-1  ;USR(2)
			.word USR_PERMIT-1  ;USR(3)
;			.word USR_REMTASK-1 ;USR()
			.word USR_SETPRI-1  ;USR(4),TASK,PRI
;			.word USR_GETPRI-1  ;USR(5),TASK
			.word USR_WAITM-1   ;USR(5),ADDR,AND[,EOR]
			.word USR_SETGRP-1  ;USR(6),TASK,GRP
			.word USR_WAIT-1    ;USR(7),MASK
			.word USR_SIGNAL-1  ;USR(8),TASK,SIG_SET
			.word USR_SLEEP-1   ;USR(9),JIFFIES
			.word USR_BORDER-1  ;USR(10),COLOR
			.word USR_BACKGND-1 ;USR(11),COLOR
			.word BASIC_SAVE-1  ;USR(12),BANK
			.word BASIC_LOAD-1  ;USR(13),BANK


USR_HANDLER	JSR AYINT
			LDA $65
			CMP #13    ; # entries in USRTBL
			bmi +
			JMP $B248  ;?ILLEGAL QUANTITY  ERROR
+			ASL
			TAY
			LDA USRTBL+1,Y
			PHA
			LDA USRTBL+0,Y
			PHA
			RTS



USR_FORK:
; save stack pointer
                SEI
                TSX
                TXA
                LDY TID
                STA SP0,Y

; Put USR_GETTID as RTI for new task
                LDA #>USR_GETTID
                PHA
                LDA #<USR_GETTID
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
                CPX #mxtasks
                BNE +
                LDX #$00
+               CPX TID
                BNE +
                LDX #16   ; OUT OF MEMORY ERROR
                JMP ERROR
+               LDA FLG0,X
                BNE -
                STX NTID
                LDA #$C0
                STA FLG0,X

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
                CLI

; Set Return code based on current Task ID
USR_GETTID:
                LDY TID
                JMP $B3A2

USR_FORBID:     JSR FORBID
                LDY TS_ENABLE
                JMP SNGFLT

USR_PERMIT:     JSR PERMIT
                LDY TS_ENABLE
                JMP SNGFLT

USR_SETPRI:     JSR COMBYT   ; TID
                JSR GET_PRI
                TYA
                PHA
                TXA
                PHA
                JSR COMBYT   ; PRI
                PLA
                TAY
                TXA
                JSR SET_PRI  ; y = TID, A = New Pri
                PLA
                TAY
                JMP SNGFLT

USR_GETPRI:     JSR COMBYT
                JSR GET_PRI  ; x = TID, y-> new Pri
                JMP SNGFLT

USR_SETGRP:     JSR COMBYT   ; TID
                JSR GET_GRP
                TYA
                PHA
                TXA
                PHA
                JSR COMBYT   ; GRP
                PLA
                TAY
                TXA
                JSR SET_GRP  ; y = TID, A = New Group
                PLA
                TAY
                JMP SNGFLT


; This call can halt the current thread
;	WAIT for any bit in mask
; signalled = USR_WAIT(mask) {
; 	1100 WAIT
;	1010 SIGNAL
;
;	Do a Task Switch no matter what
;	Treat as YIELD point even if signal already there
;
;	1000 RET (RET = WAIT & SIGNAL)
;	0010 NEW SIGNAL (SIGNAL &= ~WAIT)
;	0000 NEW WAIT (WAIT = 0)
;	return RET
; }
;
; $80 <reserved>
; $40 <timer>
; $20 <memory>
; $10 <queue>
;
USR_WAIT:       JSR COMBYT
                TXA
                JSR WAIT
                TAY
                JMP SNGFLT

; SIGNAL
; Should SIGNAL initate Task Switch?
; NO. Much easier to have task yield or wait for pre-emption
; might not be too hard.
;
; signals = USR_SIGNAL(task, signal) {
; 	signal0[task] |= signal;
; 	return signal0[task]
; }

USR_SIGNAL:		JSR COMBYT
				TXA
				PHA
				JSR COMBYT
				PLA
				TAY
				TXA
				JSR SIGNAL
				TAY
				JMP SNGFLT

USR_SLEEP:      JSR skipcomma
                JSR evalparam
                JSR convert16  ;y is lo, a is hi
                JSR SLEEP
                TAY
                JMP SNGFLT

USR_WAITM:      JSR GETNUM
                LDY TID
                TXA
                STA ANDMSK0,Y
                LDX #$00
                JSR CHRGOT
                BEQ +
                JSR COMBYT
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

USR_BORDER      JSR COMBYT
                LDY $D020
                STX $D020
                JMP SNGFLT

USR_BACKGND     JSR COMBYT
                LDY $D021
                STX $D021
                JMP SNGFLT


BASIC_SAVE:
                JSR COMBYT
                LDY #XFER_SAVE

                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH

                SEI
                JSR XFER_BASIC_XY
+               CLI
                RTS

BASIC_LOAD:
                JSR COMBYT
                LDY #XFER_LOAD

                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH

                SEI
                JSR XFER_BASIC_XY
+               CLI
                RTS
