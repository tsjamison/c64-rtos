# c64-rtos
Multitasking library module for Commodore 64 8-bit computer, inspired by FreeRTOS and Amiga OS.

Pre-Alpha

Features planned for 1st release v1.0:
* Task Group - Multi-tasking will be cooperative among tasks in same Group, but pre-emptive across Groups
* Timer device to sleep for x Jiffies
* Input device to sleep until Joystick Input
* Task Quantum for Time-Slicing
* Standardize Assembly-Language API
* Create Assembly-language demos to demonstrate Assembly/BASIC multitasking interopability

Features planned for 2nd release v2.0:
* Inter-process Communication
* Better demos
* Cleaned up source code
* Other future features upon request.


The following RTOS BASIC fuctions are implemented:
| FUNCTION   | USR Command         | Description |
| ---------- | ------------------- | ----------- |
| GET_TID    | USR(0)              | Returns Task ID of currently running Task |
| FORK       | USR(1)              | Creats a new Task based off of current Task with a copy of BASIC RAM [fork()](https://en.wikipedia.org/wiki/Fork_(system_call)) |
| FORBID     | USR(2)              | forbid task rescheduling until a matching PERMIT |
| PERMIT     | USR(3)              | permit task rescheduling |
| SETPRI     | USR(4),TASK,PRI     | Set Task Priority. High priority tasks prevent low priority tasks from running |
| GETPRI     | USR(5),TASK         | Get Task Priority. |
| WAIT       | USR(6),MASK         | Set Task to sleep, waiting for a signal in the mask to wake it up |
| SIGNAL     | USR(7),TASK,SIG_SET | Signals a Waiting Task                    |
| BORDER:    | USR(8),COLOR        | *Deprecated* - Changes Border color       |
| BACKGND:   | USR(9),COLOR        | *Deprecated* - Changer Background color   |
| BASIC_SAVE | USR(10),BANK        | *Deprecated* - Saves BASIC state to REU   |
| BASIC_LOAD | USR(11),BANK        | *Deprecated* - Loads BASIC state from REU |

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
5 print "{CLR}"
10 sys 49152:rem initialize rtos
15 z=usr(4),0,0
16 z=usr(4),1,1
17 z=usr(4),2,2
18 z=usr(4),3,0
20 t=usr(1):rem fork, returns task id
25 t=usr(1)
30 print "{HOME}"
40 for i=0 to t:print"{DOWN}";:next
50 print t "task" ti
60 goto 30
```
After all the forking, tere are 4 tasks running the same code in their own BASIC memory spaces.
The variable t has its task id, which can also be read by calling USR(0).

In a Loop, each task moves down to its own line and prints the time. That way you can see which tasks are running.

