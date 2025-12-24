; 64tass.exe -o ../release/rtos rtos.asm

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

; @todo - Decide if/how to utilise BRK




                .cpu "6502"
                *= $C000   ; 0801 BASIC header


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


; @todo - NEEDS UPDATED
CLEANUP:
                SEI
                LDA #$00
                LDY TID
                STA FLG0,Y
                STA TS
                CLI
                BRK


.include "um-ts.asm"
.include "api.asm"
.include "basicapi.asm"

; BASIC_BANK[]
; GROUP[]    No task-switching among tasks in same group until task is WAITING
; PRIORITY[]
; QUANTUM[] (Time Slice) Jiffies to run before pre-empting allowed
; WAITING[] If 0, then its runnable, A WAIT with 0 is considered a YIELD
; SIGNAL[]  Can signal before wait -- wait will return immediately
; SLEEP_TIME[] 16-bit sleep time in ticks. 0 for not sleeping


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
