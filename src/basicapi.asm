FCERR  = $B248
FOUT   = $BDDD
AYINT  = $B1BF
SNGFLT = $B3A2

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
			.word USR_SETPRI-1  ;USR(4),PRI
			.word USR_GETPRI-1  ;USR(5)
			.word USR_WAIT-1    ;USR(6),MASK
			.word USR_SIGNAL-1  ;USR(7),SIG_SET
			.word USR_BORDER-1  ;USR(8),COLOR
			.word USR_BACKGND-1 ;USR(9),COLOR
			.word BASIC_SAVE-1  ;USR(10),BANK
			.word BASIC_LOAD-1  ;USR(11),BANK
			


USR_HANDLER	JSR AYINT
			LDA $65
			CMP #12    ; # entries in USRTBL
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
; find free task
                SEI
                TSX
                TXA
                LDY TID
                STA SP0,Y

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
                LDA FLG0,X
                BNE -
                STX NTID
                LDA #$C0
                STA FLG0,X

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
USR_WAIT:       JSR COMBYT
                TXA
                LDY TID
                STA WAIT0,Y
                JSR UM_TS_PROC
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
				ORA SIGNAL0,Y
				STA SIGNAL0,Y
				TAY
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
