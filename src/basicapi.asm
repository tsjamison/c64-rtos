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
; 5   SetTaskPri <PID>,<GRP>,<PRI>
; 6   GetTaskPri <PID> PID of -1 is own PID
; 7   Wait(task, signalSet), task -1 is own task, signalSet of 0 is YIELD
; 8   Signal(task, signalSet)

USRTBL		.word USR_GETTID-1
			.word USR_FORK-1
			.word USR_FORBID-1
			.word USR_PERMIT-1
			.word USR_BORDER-1
			.word USR_BACKGND-1
			.word BASIC_SAVE-1
			.word BASIC_LOAD-1


USR_HANDLER	JSR AYINT
			LDA $65
			CMP #8    ; # entries in USRTBL
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
