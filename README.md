# c64-rtos
Multitasking library module for Commodore 64 8-bit computer, inspired by FreeRTOS and Amiga OS.

Pre-Alpha

Features planned for 1st release v1.0:
* REU Detection
* Currently only runnable task can't sleep. I think it should be sleepable.

Features planned for 2nd release v2.0:
* Join (Wait for a task to end)
* Standardize Assembly-Language API (Jump Table)
* Create Assembly-language demos to demonstrate Assembly/BASIC multitasking interopability
* Better demos
* Cleaned up source code

Features not planned, but considered:
* Tasks may share BASIC Banks with other tasks
* Task Quantum for Time-Slicing
* Multiple run-time defined IPC Queues
* Other features upon request.


The following RTOS BASIC fuctions are implemented:
| FUNCTION   | USR Command           | Description |
| ---------- | --------------------- | ----------- |
| GET_TID    | USR(0)                | Returns Task ID of currently running Task |
| FORK       | USR(1)                | Creats a new Task based off of current Task with a copy of BASIC RAM [fork()](https://en.wikipedia.org/wiki/Fork_(system_call)) |
| FORBID     | USR(2)                | forbid task rescheduling until a matching PERMIT |
| PERMIT     | USR(3)                | permit task rescheduling                         |
| REMTASK    | USR(4)[,TASK]         | End Task                                         |
| SETPRI     | USR(5),TASK,PRI       | Set Task Priority. High priority tasks prevent low priority tasks from running |
| SETGRP     | USR(6),TASK,GRP       | Set Task Group. Tasks in same group are co-operative. Tasks in different groups are pre-emptive |
| WAIT       | USR(7),MASK           | Set Task to sleep, waiting for a signal in the mask to wake it up |
| SIGNAL     | USR(8),TASK,SIG_SET   | Signals a Waiting Task                    |
| SLEEP      | USR(9),JIFFIES        | Sleeps current task for x Jiffies         |
| WAITM      | USR(10)ADDR,AND[,EOR] | Get Task Priority.                        |
| NQ:        | USR(11)STR,TASK       | eNQueue a string, notifying TASK          |
| DQ:        | USR(12),LEN           | Yield and DeQueue a string up to LEN char |

Caveats: There is no error-handling. No parameter checking for valid range.
Not every possible situation has been tested.
Must have an REU enabled with at least 1MB RAM (64KB per Task * 16 Tasks).

I/O isn't protected. Input goes to any runing task.
Each task keeps its own output state.

The border color reflects which current task is running.

DEMO STEPS:

* `load "rtos",8,1`
* `new`
* `load "demo3",8`
* `run`


The BASIC program first does a SYS call to initialize the RTOS.
Then it calls USR(1), which performs a [fork()](https://en.wikipedia.org/wiki/Fork_(system_call)),
and returns the Task ID. The original task is 0, the newly created task is 1.

Calls to USR(4) sets the priorities of each task that will be created
4 Tasks get created in this program.

Try changing the priorities to see how it affects which tasks run.

Task 2 (Red) is running because it has the highest priority.
You can put Task 2 to sleep, and allow lower priority tasks to run.
For example, if you hit STOP, then  you can issue the following:
`?usr(6),1`
That will put Task 2 to sleep waiting for signal 1, and allow Task 1 (WHITE) to run.
You can re-enable Task 2 by sending Task 2 the signal 1 it is waiting for:
`?usr(7),2,1`


```basic
10 sys 49152
20 z=usr(4),1,1:x=usr(6),1,1
30 t=usr(1)
40 if t=0 then 40
50 d=usr(5)56320,31,31-j
60 j=31-peek(56320) and 31
70 printd,j
80 goto 50
```

This code runs the main task as an idle task. A second task waits on the Joystick port 2 to change and displays the state.
