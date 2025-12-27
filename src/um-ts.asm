

UM_TS:

                JSR FORBID
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

                JSR PERMIT
                CLI

                PLA
                TAY
                PLA
                TAX
                PLA
                RTI

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


