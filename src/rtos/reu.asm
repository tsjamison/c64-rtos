;========================================================================
; reu.asm - RAM Expansion Unit: size detection and task memory transfer
; REU programming: https://codebase64.net/doku.php?id=base:reu_programming
;========================================================================

REU_STATUS      = $DF00         ; read to clear end-of-transfer flags
REU_COMMAND     = $DF01         ; B0 C64->REU, B1 C64<-REU, B2 C64<->REU, B3 C64==REU
REU_C64BASE     = $DF02         ; C64 address, 16 bits
REU_REUBASE     = $DF04         ; REU address, 24 bits (third byte = bank)
REU_TRANSLEN    = $DF07         ; transfer length, 16 bits
REU_IRQMASK     = $DF09         ; interrupt mask (unnecessary)
REU_CONTROL     = $DF0A         ; address control: $00 or $3F = both addresses count up

; REU_COMMAND values: execute at once, autoload the address registers
; afterwards, no wait for a write to $FF00
XFER_SAVE       = $B0           ; C64 -> REU
XFER_LOAD       = $B1           ; C64 <- REU
XFER_SWAP       = $B2           ; C64 <-> REU

;------------------------------------------------------------------------
; REU_SIZE - detect the REU and count its 64KB banks.
;       Writes each bank's number into byte 0 of that bank, reads them
;       back to find where the bank numbers wrap, then puts back the
;       bytes it changed.
; In:   -
; Out:  A = banks hi, X = banks lo (A/X = 0 if there is no REU)
; Uses: A X Y
;------------------------------------------------------------------------
REU_SIZE
; An REU is present if its registers keep the values written to them
                LDX #2
-               TXA
                STA REU_STATUS,X        ; $DF02-$DF05
                INX
                CPX #6
                BNE -

                LDX #2
-               TXA
                CMP REU_STATUS,X
                BEQ +

                LDA #0                  ; no REU
                LDX #0
                RTS

+               INX
                CPX #6
                BNE -

                LDA #0
                STA SIZEH
                STA REU_REUBASE+0
                STA REU_REUBASE+1
                STA REU_TRANSLEN+1
                STA REU_CONTROL
                LDA #1
                STA REU_TRANSLEN+0      ; 1 byte at a time

                LDA #<REU_TEMP
                STA REU_C64BASE+0
                LDA #>REU_TEMP
                STA REU_C64BASE+1

; Swap the bank number into byte 0 of every bank, keeping the old byte
                LDY #XFER_SWAP
                LDX #0
-               STX REU_REUBASE+2       ; bank
                STX REU_TEMP
                STY REU_COMMAND
                LDA REU_TEMP
                STA REU_TEMP+1,X
                INX
                BNE -

; Read them back: the count stops where the numbers stop going up
                LDY #XFER_LOAD
                LDX #0
                STX REU_LAST
-               STX REU_REUBASE+2       ; bank
                STY REU_COMMAND
                LDA REU_TEMP
                CMP REU_LAST
                BCC +
                STA REU_LAST
                INX
                BNE -
                INC SIZEH               ; all 256 banks
+               STX SIZEL

; Put the original bytes back, last bank first. On a small REU the
; bank numbers wrap onto the same memory, so going backwards leaves
; each real bank with its original byte.
                LDY #XFER_SAVE
                LDX #$FF
-               STX REU_REUBASE+2       ; bank
                LDA REU_TEMP+1,X
                STA REU_TEMP
                STY REU_COMMAND
                DEX
                CPX #$FF
                BNE -
                LDX SIZEL
                LDA SIZEH
                RTS


; @todo Identify global memory that shouldn't be affected by SAVE/LOAD,
; such as the time and the cursor position


;------------------------------------------------------------------------
; XFER_BASIC_XY - save or load a task's private memory to or from its
;       REU bank, at the same addresses in the bank:
;         $0002-$03FF    zero page, stack and KERNAL work area
;         VARTAB-STREND  BASIC variables and arrays
;         FRETOP-MEMSIZ  BASIC strings
;       Enter with JMP, not JSR: it continues at the address in
;       XFER_RET, because a load replaces the stack page.
; In:   X = bank (task ID), Y = XFER_SAVE or XFER_LOAD
;       XFER_RET = where to continue
; Uses: A
; Note: UM_TS and USR_FORK call it with IRQs masked. NEW_TASK saves
;       with IRQs on (FORBID held), which is safe: INT puts back
;       everything it changes in zero page.
;------------------------------------------------------------------------
XFER_BASIC_XY
; Transfer $0002-$03FF
                LDA REU_STATUS          ; clear any old status

                LDA #$3F
                STA REU_CONTROL
                LDA #$1F
                STA REU_IRQMASK

                LDA #$03                ; $03FE bytes
                STA REU_TRANSLEN+1
                LDA #$FE
                STA REU_TRANSLEN+0
                STX REU_REUBASE+2

                LDA #$00
                STA REU_C64BASE+1
                STA REU_REUBASE+1
                LDA #$02
                STA REU_C64BASE+0
                STA REU_REUBASE+0

                STY REU_COMMAND

; Transfer VARTAB-STREND, if not empty
                LDA VARTAB+0
                STA REU_C64BASE+0
                STA REU_REUBASE+0
                LDA VARTAB+1
                STA REU_C64BASE+1
                STA REU_REUBASE+1
                SEC
                LDA STREND+0
                SBC VARTAB+0
                STA REU_TRANSLEN+0
                LDA STREND+1
                SBC VARTAB+1
                STA REU_TRANSLEN+1
                BNE +
                LDA REU_TRANSLEN+0
                BEQ _strings
+               STY REU_COMMAND

; Transfer FRETOP-MEMSIZ, if not empty
_strings        LDA FRETOP+0
                STA REU_C64BASE+0
                STA REU_REUBASE+0
                LDA FRETOP+1
                STA REU_C64BASE+1
                STA REU_REUBASE+1
                SEC
                LDA MEMSIZ+0
                SBC FRETOP+0
                STA REU_TRANSLEN+0
                LDA MEMSIZ+1
                SBC FRETOP+1
                STA REU_TRANSLEN+1
                BNE +
                LDA REU_TRANSLEN+0
                BEQ _done
+               STY REU_COMMAND

_done           LDA REU_STATUS          ; clear the end-of-transfer flag
                JMP (XFER_RET)
