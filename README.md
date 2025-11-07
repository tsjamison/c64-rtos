# c64-rtos
Multitasking library module for Commodore 64 8-bit computer, inspired by FreeRTOS and Amiga OS

DEMO STEPS:

LOAD"TS",8
RUN

The BASIC program first does a SYS call to initialize the RTOS,
which prepares TASK1 to be ready to run.

TASK1 is a simple loop that only changes DATA (49160)

Setting FLG1 (49155) to 1 will activate TASK1.
Setting FLG1 (49155) to 0 will pause TASK1.

The BASIC program demonstrates this by first printing the
value of memory location 49160. It does this 10 times, demonstrating
that TASk1 is not running.

It then activates TASK1 by setting memory location 49155 to 1.

The BASIC program demonstrates TASK1 is running by printing the
value of memory location 49160. It does this 10 times, demonstrating
that TASk1 is indeed running.

It then stops TASK1 and ends the BASIC program.
```basic
10 SYS 2149
20 GOSUB 100
30 POKE 49155,1
40 GOSUB 100
50 POKE 49155,0
60 STOP
100 FOR I=0 TO 9
110 PRINT I PEEK(49160)
120 NEXT
130 RETURN
```
