FCERR  = $B248
FOUT   = $BDDD
AYINT  = $B1BF
SNGFLT = $B3A2

USRTBL		.word USR_GETTID-1
			.word USR_FORK-1
			.word USR_BORDER-1
			.word USR_BACKGND-1


USR_HANDLER	JSR AYINT
			LDA $65
			CMP #4
			bmi +
			JMP $B248  ;?ILLEGAL QUANTITY  ERROR
+			ASL
			TAY
			LDA USRTBL+1,Y
			PHA
			LDA USRTBL+0,Y
			PHA
			RTS


; USR(.)[,...]
; 0   GET PID
; 1   Fork
; 2   Forbid
; 3   Permit
; 4   RemTask(task)
; 5   SetTaskPri <PID>,<GRP/PRI>
; 6   GetTaskPri <PID> PID of -1 is own PID
; 7   Wait(task, signalSet), task -1 is own task, signalSet of 0 is YIELD
; 8   Signal(task, signalSet)

		

USR_BORDER      JSR COMBYT
                LDY $D020
                STX $D020
                JMP SNGFLT

USR_BACKGND     JSR COMBYT
                LDY $D021
                STX $D021
                JMP SNGFLT


USR_FORK:
; find free task
                SEI
                TSX
                STX SP0

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

                LDA #$C0
                STA FLG1

                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_SAVE
                LDX #$01    ; New TID
                JMP XFER_BASIC_XY

+               TSX
                STX SP1

                LDX SP0
                TXS
                CLI

; Set Return code based on current Task ID
USR_GETTID:
                LDY TID
                JMP $B3A2


BASIC_SAVE:
                JSR COMBYT
                LDY #XFER_SAVE
                SEI
                JSR XFER_BASIC_XY
                CLI
                RTS

BASIC_LOAD:
                JSR COMBYT
                LDY #XFER_LOAD
                SEI
                JSR XFER_BASIC_XY
                CLI
                RTS
