;------------------------------------------------------------------------
; C64 RTOS assembly-language jump table
;
; The one place these addresses are defined. rtos.asm checks that each
; JMP in its table lands on the address given here, and assembly programs
; that call the RTOS include this file instead of copying the addresses.
;
; Rules: entries are 3 bytes apart, starting at $C000. Add new entries
; only at the end, and never reorder or remove one.
;------------------------------------------------------------------------

RTOS_INIT       = $C000
RTOS_FORBID     = $C003
RTOS_PERMIT     = $C006
RTOS_FORK       = $C009
RTOS_ADDTASK    = $C00C         ; @todo ADD_TASK is not working yet
RTOS_ENDTASK    = $C00F
RTOS_SETPRI     = $C012
RTOS_GETPRI     = $C015
RTOS_SETCOOP    = $C018
RTOS_GETCOOP    = $C01B
RTOS_WAIT       = $C01E
RTOS_SIGNAL     = $C021
RTOS_SLEEP      = $C024
RTOS_WAITMEM    = $C027
