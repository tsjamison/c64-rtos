# c64-rtos
Multitasking library module for Commodore 64 8-bit computer, inspired by FreeRTOS and Amiga OS.

Version 0.9

## Description

This is a toolkit to add multi-tasking support to the Commodore 64. It extends BASIC with functionality accessed via the USR() functions.



## BASIC API

The following RTOS BASIC functions are implemented:
| FUNCTION   | USR Command           | Description |
| ---------- | --------------------- | ----------- |
| GET_TID    | USR(0)                | Returns Task ID of currently running Task |
| FORK       | USR(1)                | Creates a new Task based off of current Task with a copy of BASIC RAM [fork()](https://en.wikipedia.org/wiki/Fork_(system_call)) |
| FORBID     | USR(2)                | forbid task rescheduling until a matching PERMIT |
| PERMIT     | USR(3)                | permit task rescheduling                         |
| REMTASK    | USR(4)[,TASK]         | End Task                                         |
| SETPRI     | USR(5),TASK[,PRI]     | Get/Set Task Priority. High priority tasks prevent low priority tasks from running |
| SETCOOP    | USR(6),TASK[,COOP]    | Get/Set Task Co-op. Tasks in same co-op are co-operative. Tasks in different co-ops are pre-emptive |
| WAIT       | USR(7),MASK[,TIMEOUT] | Set Task to sleep, waiting for a signal in the mask to wake it up |
| SIGNAL     | USR(8),TASK,SIG_SET   | Signals a Waiting Task                    |
| SLEEP      | USR(9),JIFFIES        | Sleeps current task for x Jiffies         |
| WAITM      | USR(10)ADDR,AND[,EOR[,TIMEOUT]] | Multitasking-friendly WAIT: sleep until memory matches |
| NQ         | USR(11)STR,TASK[,TIMEOUT] | eNQueue a message on TASK's queue         |
| DQ         | USR(12)[,TIMEOUT]     | DeQueue the next message from own queue   |
| MAXTASKS   | USR(13)               | Maximum number of tasks                   |
| STATE      | USR(14),TASK          | Returns Task State of TASK                |
| SETQTM     | USR(5),TASK[,QUANTUM] | Get/Set Task Quantum. 1=FreeRTOS, 4=AmigaOS 2.0+, 16=AmigaOS 1.3 |


### USR(0) - GET TASK ID
Returns Task ID of the currently running process.

Parameters: <None>  
Returns: Task ID

Example:
```
print usr(0)
```

### USR(1) - FORK
Creates a new Task based off of current Task with a copy of BASIC RAM [fork()](https://en.wikipedia.org/wiki/Fork_(system_call))

Parameters: <None>  
Returns: Task ID

Example:
```
t=usr(1)
```
This duplicates the current process, with the task number getting returned.
This results in now two copies of the program getting executed at the same time.
The original copy usr(1) returns the newly allocated ID. The newly created copy returns 255.

The new task starts with the parent's priority and co-op, and with no pending signals, sleep timer or wait. Because it shares the parent's co-op, it can't run until the parent waits or yields, or until it is moved to another co-op with USR(6).

### USR(2) - FORBID
Prevents other tasks from being scheduled to run by the dispatcher, until a matching Permit() is executed.

Parameters: <None>  
Returns: Current Forbid level. Need that many PERMIT to re-enable task switching.

Each task has its own Forbid level, as in AmigaOS. If a task waits or sleeps while forbidden (USR(7), USR(9), USR(10) or USR(12)), the other tasks run and pre-empt each other normally, and the task's Forbid level is back when it resumes. A new task starts at level 0, and a task that ends while forbidden takes its level with it. FORBID and PERMIT only change the calling task's level.

### USR(3) - PERMIT
Allows other tasks to be scheduled when paired with matching FORBID.

Parameters: <None>  
Returns: Current Forbid level. Need that many PERMIT to re-enable task switching.
0 means that task switching is enabled.

### USR(4)[,TASK] - END TASK
Ends the task specified by the optional parameter, or ends the task of the caller
if the task ID is not provided.

Parameters: Task ID (Optional)  
Returns: 0

### USR(5),TASK,PRI - Set Priority
Sets the priority of the task given by the parameter.
The next task that is ready task with the highest priority
will be scheduled to run.

Parameters: Task ID, Priority  
Returns: Previous priority

### USR(6),TASK,COOP - Set Co-op
Sets the co-op of the task given by the parameter.
A task can not interrupt another task in the same co-op, but may interrupt tasks in other co-ops.

Co-ops are numbered 0-15; any other value gives ?ILLEGAL QUANTITY ERROR. Every task starts in co-op 0, so tasks are cooperative until they are put in different co-ops.

A co-op is held by the task in it that last ran, until that task waits, yields or ends. While it is held, the other tasks in that co-op can't run, even if the holder is pre-empted by a task in another co-op. Moving a task to another co-op releases the old one.

Parameters: Task ID, Co-op (0-15)  
Returns: Previous co-op

### USR(7),MASK - Wait
This function will cause the current task to suspend waiting for
one or more signals.  When one or more of the specified signals
occurs, the task will return to the ready state, and those signals
will be cleared.

If a signal occurred prior to calling Wait(), the wait condition will
be immediately satisfied, and the task will continue to run without
delay.

The function takes a bit mask as an argument, specifying which of the task's 8 available signals it is interested in.
The task resumes execution when any of the specified signals are sent to it by another task, an interrupt, or an I/O event. The Wait call returns a mask indicating which signals were active when the task awoke, allowing the program to determine the cause of the event.

This function is considered "low level".  Its main purpose is to
support multiple higher level functions like Sleep and WaitMem.

Parameters: MASK  
Returns: bit-mask of signals that awoke the task

### USR(8),TASK,SIG_SET - Signal
This function signals a task with the given signals.  If the task
is currently waiting for one or more of these signals, it will be
made ready and a reschedule will occur. If the task is not waiting
for any of these signals, the signals will be posted to the task
for possible later use. A signal may be sent to a task regardless
of whether its running, ready, or waiting.

This function is considered "low level".  Its main purpose is to
support multiple higher level functions like Sleep and WaitMem.
7654 3210

TIMER_SIGNAL = $40  (1 << 6)
WAITM_SIGNAL = $20  (1 << 5)
QUEUE_SIGNAL = $10  (1 << 4)

Signal $80 (1 << 7) is reserved for future use by RTOS
The 4 signals in the lower nibble are available for application use.

Parameters:  
    task - the task to be signalled  
    signals - the signals to be sent  
Returns: The task's signal set after the signal is posted.

### USR(9),JIFFIES - Sleep
Puts the running task to sleep for so many JIFFIES (1/60th of a second), 60 JIFFIES for 1 second.

Parameters:  
    JIFFIES - 0-65535 JIFFIES  
Returns:  bit-mask of signals that awoke the task

### USR(10)ADDR,AND[,EOR] - WAIT MEMORY
This function works identically to the WAIT command, but does so in a multitasking-friendly way. The task will sleep until the address matches the given AND and EOR bits.

Parameters:  
    ADDR  
    AND  
    EOR  
Returns: Bitmask of the result

### USR(11)STR,TASK - Send STR as a message to TASK's queue

Each task has its own 16-byte queue of messages. Any task can send to any task's queue, its own included; only the task itself can read it, with USR(12).
A message is 0-15 bytes. In the queue it takes one length byte plus its bytes, so one 15-byte message, two 7-byte messages or sixteen empty ones fill a queue.

Parameters:  
    STR - The message, 0-15 bytes. Longer gives ?ILLEGAL QUANTITY ERROR  
    TASK - Task whose queue gets the message. It is sent the queue signal (16)  
Returns: LEN(STR), or -1 if the message was not sent.

A message is sent whole or not at all, so messages from different tasks never mix.
If the queue doesn't have room, USR(11) waits until TASK has read enough.
It returns -1 without sending if TASK is the running task and its own queue lacks room (nobody else could empty it), or if TASK ends while it waits.
An empty string sends an empty message: use it to wake a task waiting in USR(12).
If TASK is waiting in USR(12), it runs straight away if its priority allows.

Example:
```
a=usr(11)"hello",0
b$="world!"
b=usr(11)b$,0
```
a will have 5, and b will have 6

### USR(12) - Receive the next message from the task's own queue

Parameters: <None>  
Returns: the message as a string ("" for an empty message).

Waits until the running task's queue holds a message, then returns it. Each call returns exactly one message, as it was sent.
A new task starts with an empty queue.
The queue signal (16) only means "the queue changed": it is not kept set while messages are waiting, so check with USR(12), not USR(7),16.

Example:
```
a=usr(11)"hello",0:a=usr(11)"world!",0
a$=usr(12):b$=usr(12)
```
a$ will have "hello", and b$ will have "world!"

### USR(13) - Return Maximum number of tasks the system supports

Example:
```
print usr(13)
```

### USR(14),TASK - Return task state of given TASK

TS_INVALID = 0  
TS_RUN     = 2  
TS_READY   = 3  
TS_WAIT    = 4  
TS_COOPTED = 7  
TS_PREEMPT = 8  

TS_COOPTED means the task is ready but another task holds its co-op. TS_PREEMPT means the task holds its co-op but was pre-empted by a task in another co-op.

TS_ADDED (1), TS_EXCEPT (5) and TS_REMOVED (6) are defined in the source but not currently used.

Parameters:  
    TASK - Task ID to get task state  
Returns: task state

## Notes

Some parameters are checked and give ?ILLEGAL QUANTITY ERROR when out of range: the USR number (0-14), task IDs (0 to USR(13)-1) for USR(4), USR(5), USR(6), USR(8), USR(11) and USR(14), co-op numbers (0-15) and USR(11) message lengths (0-15). Other values, such as priorities and signal masks, are not checked.
Not every possible situation has been tested.
Requires an REU. Each task uses one 64KB REU bank, up to 16 tasks: a 1MB or larger REU gives 16 tasks, 512KB gives 8, 256KB gives 4 and 128KB gives 2.

I/O isn't protected. Input goes to any running task.
Each task keeps its own output state.

Each task has its own copy of zero page, the stack, $0200-$03FF, its variables and its strings. The BASIC program text, screen RAM and memory above $A000 are shared. This has some side effects:

* Don't edit or LOAD the BASIC program while other tasks are running. Program text is shared but each task has its own variable pointers, so changing the program corrupts every other task's variables.
* TI and TI$ are per task. The jiffy clock lives in zero page, so a task's clock only advances while that task is running.
* The keyboard buffer is per task, so keystrokes can be lost or go to whichever task happens to be running.
* WAITM reads its address every jiffy. Avoid registers that change when read, such as the CIA interrupt register at $DC0D.

The border color reflects which current task is running. When no task is ready to run, the border cycles through colors on every pass of the scheduler's idle loop, so idle time shows as stripes in the border.



## Demos

### Joystick Demo

```basic
10 sys 49152
20 t=usr(1)
30 if t=0 then z=usr(5),1,1:x=usr(6),1,1
40 if t=0 then 40
50 d=usr(10)56320,31,31-j
60 j=31-peek(56320) and 31
70 printd,j
80 goto 50
```

This code runs the main task as an idle task. A second task waits on the Joystick port 2 to change and displays the state.

Task 0 forks first, then sets the new task's priority and co-op. A new task starts with its parent's settings, so settings made for a slot before the fork would be overwritten.

## Planned features

### Features planned for 1st release v1.0:
* Change SETPRI and SETCOOP to be GET/SET with new setting as an optional parameter.
* Add optional Timeout parameters - WAITM EOR parameter will now be required
* Join (Wait for a task to end)
* Move TI and TI$ from per task to global.
* Move the keyboard buffer from per task to global.
* Standardize Assembly-Language API (Jump Table)
* Create Assembly-language demos to demonstrate Assembly/BASIC multitasking interopability

### Open Questions for v1.0:
* Should other data currently stored in the REU per task be global in addition to TI/TI$ and keyboard buffer?
* Should USR table be re-organized to group similar functions together?
* Instead of USR, should new BASIC tokens be created? Multiple ways to hook new keywords. This library should be compatible with other BASIC expanders like EPYX BASIC Toolkit or Simon's BASIC.

### Features not planned, but considered:
* Tasks may share BASIC Banks with other tasks
* Task Quantum for Time-Slicing
* Multiple run-time defined IPC Queues
* Other features upon request.
