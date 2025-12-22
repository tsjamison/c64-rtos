; 64tass.exe TS.ASM -o ts.prg
; 64tass.exe UM-TS.ASM -o um-ts.prg -l um-ts.txt

USRADD = $0311
CINV   = $0314
TIME_SLICES = 0    ; Unit is Jiffies, 1/60 of a second
COMBYT = $B7F1
VARTAB = $2D
STREND = $31
FRETOP = $33
MEMSIZ = $37


; 6502 Interrupt:
; Push Return address High
; Push Return address low
; Push Status
; JMP ($FFFE) -> FF48
; Push A
; Push X
; Push Y
; Check Status Interrupt bit
; JMP ($0316) if clear (BRK isntruction)
; JMP ($0314) if set

; STACK PAGED IN
; ACTIVE
; GROUP    [2]
; PRIORITY [3]






END    = $80
FOR    = $81
NEXT   = $82
GOTO   = $89
IF     = $8b
GOSUB  = $8d
RETURN = $8e
STOP   = $90
POKE   = $97
PRINT  = $99
SYS    = $9e
TO     = $a4
THEN   = $a7
EQU    = $b2
USR    = $b7
PEEK   = $c2

;10 sys 49152
;20 t=usr(1)
;30 if t=1 then 100
;40 print "hello, world" ti
;50 goto 40
;100 fori=0to15:poke53281,i:next:goto100



                .cpu "6502"
                *= $C000   ; 0801 BASIC header

;  7 Ready to Run
;  6 BASIC task, if set, then all BASIC data is saved to REU
;5-3 Group    (0-7)  // tasks can pre-empt tasks from a different Group
;2-0 Priority (0-7)  // 0 is lowest priority (initial task is idle task)

; INITSTACK
start           SEI

; Compare Vector Table
                LDA CINV
                CMP #<INT
                BNE install
                LDA CINV+1
                CMP #>INT
                BEQ skip_install

install
                LDA CINV
                STA IRQL
                LDA CINV+1
                STA IRQH
    
                LDA #<INT
                STA CINV
                LDA #>INT
                STA CINV+1

skip_install
; reset variables
                LDA #$00
                STA TID  ;TASK ID
                STA TS
                STA FLG1  ;CLEAR ENABLE FLAG for TASK 1
                LDA #$C0  ; Ready, BASIC, Group 0 Pri 0
                STA FLG0  ;SET ENABLE FLAG

; Initialize USR() pointer
                LDA #<BASIC_FORK
                STA $0311
                LDA #>BASIC_FORK
                STA $0312

                LDA #$01
                STA TS_ENABLE

                CLI
                RTS


addtask
;SAVE CURRENT STACK POINTER
                TSX
                STX SP0
; SET UP TASK1 RTS DESTINATION
                LDX #$7F
                TXS
                LDA #>CLEANUP
                PHA
                LDA #<CLEANUP-1
                PHA

; SET UP TASK1 START
                LDA #>TASK1
                PHA
                LDA #<TASK1
                PHA
                LDA #$20
                PHA       ;STATUS REGISTER
                LDA #$00
                PHA       ;ACC
                PHA       ;X
                PHA       ;Y
                TSX
                STX SP1
    
                STA FLG1  ;SET ENABLE FLAG
                LDX SP0
                TXS
                RTS


; USR(.)[,...]
; 0   GET PID
; 1   Fork
; 2   Forbid
; 3   Permit
; 4   RemTask(task)
; 5   SetTaskPri <PID>,<GRP/PRI>
; 6   GetTaskPri <PID>
; 7   Wait(task, signalSet)
; 8   Signal(task, signalSet)

; BASIC_BANK[]
; GROUP[]
; PRIORITY[]
; QUANTUM[] (Time Slice) Jiffies to run before pre-empting allowed
; WAITING[] If 0, then its runnable
; SIGNAL[]  Can signal before wait -- wait will return immediately

; TID = Current Task ID
; NTID = Next Task ID
;Pre-emptSelectNextTask()
;{
;	NTID = TID;  // Should already be true
;	Current_Quantum--;
;	if (Current_Quantum < 0) {
;		task = TID;
;		next_pri = PRIORITY[TID];
;		do {
;			if (task == 0) {
;				task = MAX_TASKS;
;			}
;			task--;
;			if (WAITING[task] == 0
;			 && GROUP[task] != GROUP[TID]
;			 && PRIORITY[task] >= next_pri) {
;				NTID = task;
;				next_pri = PRIORITY[task];
;			}
;		} while (task != TID);
;	}
;}

; WAIT
; If Signal already received, then return, no TS
; Set Wait flag, Find next Task (ANY)

; SIGNAL
; If Signalled task was WAITING & same or higher priority, do TS
; return



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

; TASK SWITCH INTERRUPT
INT:
                LDA TS_ENABLE  ; 0 MEANS TASK SWITCH DISABLED
                BEQ INTEND

                DEC TS
                BPL INTEND
                LDA #TIME_SLICES
                STA TS

                LDY TID
INT2:
                INY
                CPY #$02  ;MAX TASKS
                BNE +
                LDY #$00
+
                LDA FLG0,Y
                BEQ INT2
                CPY TID
                BEQ INTEND
                STY NTID

; Y has next task to run
; cmp y withh TID
; if same, then don't task switch

; Prepare task-switch task
; Push Return address High
; Push Return address low
; Push Status
; Push A
; Push X
; Push Y
                LDA #>UM_TS
                PHA
                LDA #<UM_TS
                PHA
                LDA #$20
                PHA
                LDA #$00
                PHA
                PHA
                PHA


;                LDX SP0,Y
;                TXS


INTEND:
                JMP (IRQL)

CLEANUP:
                SEI
                LDA #$00
                LDY TID
                STA FLG0,Y
                STA TS
                CLI
                BRK

UM_TS:

                LDA #$00
                STA TS_ENABLE
                LDA #TIME_SLICES
                STA TS
                TSX
                TXA
                LDY TID
                STA SP0,Y

                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH
                LDY #XFER_SAVE
                LDX TID
                SEI
                JMP XFER_BASIC_XY 

+
                LDA #<+
                STA RTSL
                LDA #>+
                STA RTSH

                LDY #XFER_LOAD
                LDX NTID
                STX TID
                STX $D020
                JMP XFER_BASIC_XY

+               LDY TID
                LDX SP0,Y
                TXS

                LDA #$01
                STA TS_ENABLE
                CLI

                PLA
                TAY
                PLA
                TAX
                PLA
                RTI


TASK1:
                INC DATA
                JMP TASK1

; REU https://codebase64.net/doku.php?id=base:reu_programming
status   = $DF00
command  = $DF01   ; B0 C64->REU, B1 C64<-REU, B2 C64<->REU, B3 C64==REU
c64base  = $DF02
reubase  = $DF04
translen = $DF07
irqmask  = $DF09   ; unnecessary
control  = $DF0A   ; 0x3F

; Need to identify GLOBAL memory that shouldn't be affected by SAVE/LOAD
; Such as Time
; Cursor position?


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

XFER_SAVE = $B0
XFER_LOAD = $B1

; X is bank#
; Y is command
XFER_BASIC_XY:
; xfer $0000 - $03FF
                LDA status

                LDA #$3F
                STA control
                LDA #$1F
                STA irqmask

                LDA #$03
                STA translen+1
                LDA #$FE
                STA translen+0
                STX reubase+2

                LDA #$00
                STA c64base+1
                STA reubase+1
                LDA #$02
                STA c64base+0
                STA reubase+0

                STY command

; xfer VARTAB - STREND
                LDA VARTAB+0
                STA c64base+0
                STA reubase+0
                LDA VARTAB+1
                STA c64base+1
                STA reubase+1
                SEC
                LDA STREND+0
                SBC VARTAB+0
                STA translen+0
                LDA STREND+1
                SBC VARTAB+1
                STA translen+1
                BNE +
                LDA translen+0
                BEQ ++
+               STY command

; xfer FRETOP - MEMSIZ
+               LDA FRETOP+0
                STA c64base+0
                STA reubase+0
                LDA FRETOP+1
                STA c64base+1
                STA reubase+1
                SEC
                LDA MEMSIZ+0
                SBC FRETOP+0
                STA translen+0
                LDA MEMSIZ+1
                SBC FRETOP+1
                STA translen+1
                BNE +
                LDA translen+0
                BEQ ++
+               STY command

+               LDA status
                JMP (RTSL)



TS_ENABLE       .BYTE ?
SP0:            .BYTE ?
SP1:            .BYTE ?
FLG0:           .BYTE ?
FLG1:           .BYTE ?
TS:             .BYTE ?
TID:            .BYTE ?
NTID:           .BYTE ?

IRQL:           .BYTE ?
IRQH:           .BYTE ?

RTSL:           .BYTE ?
RTSH:           .BYTE ?

DATA:           .BYTE ?
