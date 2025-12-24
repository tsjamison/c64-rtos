
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


BASIC_FORK:
; find free task
                ;JSR COMBYT
                ;STX $D020
                ;LDY $D020
                ;JMP $B3A2

                SEI
                TSX
                STX SP0

                LDA #>BASIC_FORK_2
                PHA
                LDA #<BASIC_FORK_2
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
BASIC_FORK_2:
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
