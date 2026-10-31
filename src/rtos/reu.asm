; REU https://codebase64.net/doku.php?id=base:reu_programming
status   = $DF00
command  = $DF01   ; B0 C64->REU, B1 C64<-REU, B2 C64<->REU, B3 C64==REU
c64base  = $DF02
reubase  = $DF04
translen = $DF07
irqmask  = $DF09   ; unnecessary
control  = $DF0A   ; 0x3F

XFER_SAVE = $B0
XFER_LOAD = $B1
XFER_SWAP = $B2
         ;DETECT REU SIZE

REU_SIZE:
                LDX #2
-               TXA
                STA $DF00,X
                INX
                CPX #6
                BNE -
		        
                LDX #2
-               TXA
                CMP $DF00,X
                BEQ +
		        
                LDA #0
                LDX #0
                RTS
		        
+               INX
                CPX #6
                BNE -
		        
                LDA #0
                STA SIZEH
                STA reubase+0
                STA reubase+1
                STA translen+1
                STA control
                LDA #1
                STA translen+0
		        
                LDA #<TEMP
                STA c64base+0
                LDA #>TEMP
                STA c64base+1
		        
                LDY #XFER_SWAP
                LDX #0
-               STX reubase+2   ;bank
                STX TEMP
                STY command
                LDA TEMP
                STA TEMP+1,X
                INX
                BNE -
		        
                LDY #XFER_LOAD
                LDX #0
                STX OLD
-               STX reubase+2   ;bank
                STY command
                LDA TEMP
                CMP OLD
                BCC +
                STA OLD
                INX
                BNE -
                INC SIZEH
+               STX SIZEL
		        
                LDY #XFER_SAVE
                LDX #$FF
-               STX reubase+2   ;bank
                LDA TEMP+1,X
                STA TEMP
                STY command
                DEX
                CPX #$FF
                BNE -
                LDX SIZEL
                LDA SIZEH
                RTS






; Need to identify GLOBAL memory that shouldn't be affected by SAVE/LOAD
; Such as Time
; Cursor position?




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


