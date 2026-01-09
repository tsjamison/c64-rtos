; 64tass.exe -o ../release/rtos rtos.asm

USRADD = $0311
CINV   = $0314
TIME_SLICES = 0    ; Unit is Jiffies, 1/60 of a second
COMBYT = $B7F1
VARTAB = $2D
STREND = $31
FRETOP = $33
MEMSIZ = $37
mxtasks = 8

TIMER_SIGNAL = $40





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
                LDY #mxtasks-1
-               STA FLG0,Y     ;CLEAR ENABLE FLAG FOR TASKS 1..mxtasks-1
                STA PRI0,Y     ;CLEAR PRIORITY ARRAY
                STA GRP0,Y     ;CLEAR GROUP ARRAY
                STA WAIT0,Y    ;CLEAR WAIT ARRAY
                STA SIGNAL0,Y  ;CLEAR SIGNAL ARRAY
                STA SLEEP0,Y   ;CLEAR SLEEP ARRAY LO
                STA SLEEP1,Y   ;CLEAR SLEEP ARRAY HI
                DEY
                BPL -
                LDA #$C0  ; Ready, BASIC, Group 0 Pri 0
                STA FLG0  ;SET ENABLE FLAG

; Initialize USR() pointer
                LDA #<USR_HANDLER
                STA $0311
                LDA #>USR_HANDLER
                STA $0312

                LDA #$00
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
;		if (WAITING) group = NO_GRP;
;       else group = GROUP[TID]
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
; If Signal already received, then return, no task switch
; Set Wait flag, Find next Task (ANY)

; SIGNAL
; If Signalled task was WAITING & same or higher priority, do task switch
; return

;@todo How to force Task Switch logic from Wait()?


; TASK SWITCH INTERRUPT
INT:

; @todo Before checking if TS is Permitted:
; @todo Update Timer / Input Devices
; @todo Update Quantum

; If SLEEP counter is 0, then skip
                LDX #mxtasks-1
-               LDA SLEEP0,X
                ORA SLEEP1,X
                BEQ ++

; Decrement SLEEP counter
                LDA SLEEP0,X
                BNE +
                DEC SLEEP1,X
+               DEC SLEEP0,X

; If SLEEP counter is still running, then skip
                LDA SLEEP1,X
                ORA SLEEP0,X
                BNE +

; SIGNAL task, because SLEEP timer just elapsed
                LDA #TIMER_SIGNAL
                ORA SIGNAL0,X
                STA SIGNAL0,X

+               DEX
                BPL -

                LDA TS_ENABLE  ; 0 MEANS TASK SWITCH ENABLED
                BNE INTEND


; Prepare task-switch task
; Push Return address High
; Push Return address low
; Push Status
; Push A
; Push X
; Push Y
                LDY TID
                LDA GRP0,Y
                STA GROUP
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
                CLI
                BRK


.include "um-ts.asm"
.include "api.asm"
.include "basicapi.asm"

; BASIC_BANK[]
; GROUP[]    No task-switching among tasks in same group until task is WAITING
; PRIORITY[]
; QUANTUM[] (Time Slice) Jiffies to run before pre-empting allowed
; WAITING[] If 0, then its runnable
; SIGNAL[]  Can signal before wait -- wait will return immediately
; SLEEP_TIME[] 16-bit sleep time in ticks. 0 for not sleeping


TS_ENABLE       .BYTE ?
SP0:            .fill mxtasks
FLG0:           .fill mxtasks
PRI0:           .fill mxtasks
GRP0:           .fill mxtasks
WAIT0:          .fill mxtasks
SIGNAL0:        .fill mxtasks
SLEEP0:         .fill mxtasks
SLEEP1:         .fill mxtasks
TID:            .BYTE ?
NTID:           .BYTE ?
MXPRI:          .BYTE ?
GROUP:          .BYTE ?

IRQL:           .BYTE ?
IRQH:           .BYTE ?

RTSL:           .BYTE ?
RTSH:           .BYTE ?

DATA:           .BYTE ?
