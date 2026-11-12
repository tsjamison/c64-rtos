;========================================================================
; test.asm - assembly-language test of the RTOS jump table
;
; Load the RTOS first, then this program, and SYS 32768.
; Task 0 counts at the top-left of the screen every 300 jiffies (5 s);
; task 1 counts in the next character every 60 jiffies (1 s).
; Build:    64tass -o test.prg test.asm
;========================================================================

                .include "rtos/jumptable.inc"

SCREEN          = $0400         ; screen RAM

                .cpu "6502"
                * = $8000       ; SYS 32768

                JSR RTOS_INIT
                JSR RTOS_FORK           ; Y = task ID
                CPY #$01
                BEQ _task1

; Task 0 (and any task other than 1)
-               INC SCREEN
                LDA #>300               ; sleep 300 jiffies (A = hi, Y = lo)
                LDY #<300
                JSR RTOS_SLEEP
                JMP -

; Task 1
_task1
-               INC SCREEN+1
                LDA #>60                ; sleep 60 jiffies
                LDY #<60
                JSR RTOS_SLEEP
                JMP -
