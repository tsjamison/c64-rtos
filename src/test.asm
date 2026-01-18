RTOS_INIT       = $C000
RTOS_FORBID     = $C003
RTOS_PERMIT     = $C006
RTOS_FORK       = $C009
RTOS_ADDTASK    = $C00C
RTOS_ENDTASK    = $C00F
RTOS_SETPRI     = $C012
RTOS_GETPRI     = $C015
RTOS_SETGRP     = $C018
RTOS_GETGRP     = $C01B
RTOS_WAIT       = $C01E
RTOS_SIGNAL     = $C021
RTOS_SLEEP      = $C024
RTOS_WAITMEM    = $C027


                .cpu "6502"
                *= $8000   ; 0801 BASIC header
				
				JSR RTOS_INIT
				JSR RTOS_FORK
				CPY #$01
				BEQ +
-				INC $0400
				LDA #$01
				LDY #$2C
				JSR RTOS_SLEEP
				JMP -
+
-               INC $0401
				LDA #$00
				LDY #$3C
				JSR RTOS_SLEEP
                JMP -