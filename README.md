# c64-rtos
Multitasking library module for Commodore 64 8-bit computer, inspired by FreeRTOS and Amiga OS

PROOF-OF-CONCEPT

Right now, there is a limit of 2 tasks, there is no error-handling.
Must have an REU enabled with at least 128KB RAM.

I/O isn't protected, so it gets weird if two tasks try to print at same time.

DEMO STEPS:

`LOAD"UM-TS",8,1`

The BASIC program first does a SYS call to initialize the RTOS.
Then it calls USR(), which performs a [fork()](https://en.wikipedia.org/wiki/Fork_(system_call)),
and returns the Task ID. The original task is 0, the newly created task is 1.

Task 0 prints "HELLO, WORLD" in a loop
Task 1 changes the color of the screen in a loop.

```basic
10 sys 49152:rem initialize rtos
20 t=usr(1):rem fork, returns task id
30 if t=1 then 100:rem code splits
40 print "hello, world" ti
50 goto 40
100 fori=0to15:poke53281,i:next:goto100
```
