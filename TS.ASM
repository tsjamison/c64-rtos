; cl65.exe -t cx16 -o TS.PRG TS.ASM
; 64tass.exe TS.ASM -o ts.prg

IRQVL = $0314
IRQVH = $0315
TIME_SLICES = 2    ; Unit is Jiffies, 1/60 of a second

; 6502 Interrupt:
; Push Return address High
; Push Return address low
; Push Status
; JMP ($FFFE) -> FF48
; Push A
; Push X
; Push Y
; Check Status Interrupt bit
; JMP ($0316) if clear
; JMP ($0314) if set

; STACK PAGED IN
; ACTIVE
; GROUP    [2]
; PRIORITY [3]

FOR    = $81
NEXT   = $82
GOSUB  = $8d
RETURN = $8e
STOP   = $90
POKE   = $97
PRINT  = $99
SYS    = $9e
TO     = $a4
EQU    = $b2
PEEK   = $c2
                .cpu "6502"
                *= $0801   ; BASIC header
                .word (+), 10
                .null SYS, format("%d", start)
+               .word (+), 20
                .null GOSUB, "100"
+               .word (+), 30
                .null POKE, format("%d,1", FLG1)
+               .word (+), 40
                .null GOSUB, "100"
+               .word (+), 50
                .null POKE, format("%d,0", FLG1)
+               .word (+), 60
                .null STOP
+               .word (+), 100
                .null FOR, "I", EQU, "0", TO, "9"
+               .word (+), 110
                .null PRINT, "I", PEEK, "(49160)"
+               .word (+), 120
                .null NEXT
+               .word (+), 130
                .null RETURN
+               .word 0

; INITSTACK
start           SEI
                TSX
                STX SP0         ;SAVE CURRENT STACK POINTER

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
                STA TID  ;TASK ID
                LDA #$01
                STA FLG0  ;SET ENABLE FLAG
    
                LDA IRQVL
                STA IRQL
                LDA IRQVH
                STA IRQH
    
                LDA #TIME_SLICES  ;60 JIFFIES PER SECOND
                STA TS
    
                LDA #<INT
                STA IRQVL
                LDA #>INT
                STA IRQVH
    
                LDX SP0
                TXS
                CLI
                RTS
    

INT:
                DEC TS
                BPL INTEND
                LDA #TIME_SLICES
                STA TS
                TSX
                TXA
                LDY TID
                STA SP0,Y
INT2:
                INY
                CPY #$02  ;MAX TASKS
                BNE INT1
                LDY #$00
INT1:
                STY TID
                LDA FLG0,Y
                BEQ INT2
                LDX SP0,Y
                TXS

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

TASK1:
                INC DATA
                JMP TASK1

;0899
* = $c000
SP0:            .BYTE ?
SP1:            .BYTE ?
FLG0:           .BYTE ?
FLG1:           .BYTE ?
TS:             .BYTE ?
TID:            .BYTE ?

IRQL:           .BYTE ?
IRQH:           .BYTE ?

DATA:           .BYTE ?
