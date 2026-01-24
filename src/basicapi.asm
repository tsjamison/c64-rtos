POKER     = $14
INDEX1    = $22
ANDMSK    = $49
EORMSK    = $4A
DSCTMP    = $61
CHRGOT    = $79
ERROR     = $A437
STROUT    = $AB1E
evalparam = $AD9E
FRMEVL    = $AD9E
skipcomma = $AEFD
AYINT     = $B1BF
FCERR     = $B248
SNGFLT    = $B3A2
STRSPA    = $B47D
PUTNEW    = $B4CA
PREAM     = $B761
LEN1      = $B782
GETNUM    = $B7EB
COMBYT    = $B7F1
convert16 = $B7F7
LINPRT    = $BDCD
FOUT      = $BDDD


USRTBL		.word USR_GETTID-1   ;USR(0)
			.word USR_FORK-1     ;USR(1)
			.word USR_FORBID-1   ;USR(2)
			.word USR_PERMIT-1   ;USR(3)
			.word USR_REMTASK-1  ;USR(4)[,TASK]
			.word USR_SETPRI-1   ;USR(5),TASK,PRI
			.word USR_SETGRP-1   ;USR(6),TASK,GRP
			.word USR_WAIT-1     ;USR(7),MASK
			.word USR_SIGNAL-1   ;USR(8),TASK,SIG_SET
			.word USR_SLEEP-1    ;USR(9),JIFFIES
			.word USR_WAITM-1    ;USR(10)ADDR,AND[,EOR]
			.word USR_NQ-1       ;USR(11)STR,TASK
			.word USR_DQ-1       ;USR(12),LEN
			.word USR_MAXTASKS-1 ;USR(13)
			.word USR_STATE-1    ;USR(14),TASK


USR_HANDLER	JSR AYINT
			LDA $65
			CMP #15    ; # entries in USRTBL
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
                CLI


; Set Return code based on current Task ID
USR_GETTID:
                LDY TID
                JMP SNGFLT

USR_FORBID:     JSR FORBID
                LDY TS_ENABLE
                JMP SNGFLT

USR_PERMIT:     JSR PERMIT
                LDY TS_ENABLE
                JMP SNGFLT

USR_MAXTASKS:
                LDY MAX_TASKS
                JMP SNGFLT


USR_STATE:
                JSR COMBYT   ; TID
                JSR GET_STATE
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

USR_NQ:         JSR FRMEVL
                JSR LEN1
                STY NEWL

                LDA INDEX1+1
                PHA
                LDA INDEX1+0
                PHA

                JSR COMBYT
                STX NEWH

                PLA
                STA INDEX1+0
                PLA
                STA INDEX1+1

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

                JMP SNGFLT


; Don't wait if data is available
USR_DQ:
                JSR COMBYT              ; Get required LEN parameter
                JSR DEQUEUE
		; Remove the RTS address for function from the stack
		; to avoid Type Mismatch error
                PLA
                PLA
                JMP PUTNEW              ; Return new BASIC string

USR_REMTASK:
                LDX TID
                JSR CHRGOT
                BEQ +
                JSR COMBYT
+               LDA #TS_INVALID
                STA TASK_STATE0,X
                JSR UM_TS_PROC   ; Will never come back
                LDY #$00
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
