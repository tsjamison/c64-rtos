# c64-rtos
Multitasking library module for Commodore 64 8-bit computer, inspired by FreeRTOS and Amiga OS.

Version 0.9

## Description

This is a toolkit to add multi-tasking support to the Commodore 64. It extends BASIC with functionality accessed via the USR() functions.



## BASIC API

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

### USR(0) - GET TASK ID
Returns Task ID of the currently running process.

Parameters: <None>  
Returns: Task ID

Example:
```
print usr(0)
```

### USR(1) - FORK
Creats a new Task based off of current Task with a copy of BASIC RAM [fork()](https://en.wikipedia.org/wiki/Fork_(system_call))

Parameters: <None>  
Returns: Task ID

Example:
```
t=usr(1)
```
This duplicates the current process, with the task number getting returned.
This results in now two copies of the program getting executed at the same time.
The original copy usr(1) returns 0. The newly created copy returns usr(1).

### USR(2) - FORBID
Prevents other tasks from being scheduled to run by the dispatcher, until a matching Permit() is executed.

Parameters: <None>  
Returns: Current Forbid level. Need that many PERMIT to re-enable task switching.

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

### USR(6),TASK,GROUP - Set Group
Sets the group of the task given by the parameter.
A task will never interrupt another task in the same group.

### USR(7),MASK - Wait
This function will cause the current task to suspend waiting for
one or more signals.  When one or more of the specified signals
occurs, the task will return to the ready state, and those signals
will be cleared.

If a signal occurred prior to calling Wait(), the wait condition will
be immediately satisfied, and the task will continue to run without
delay.

The function takes a bit mask as an argument, specifying whihch of the task's 8 available signals it is interested in.
The task resumes execution when any of the specified signals are sent to it by another task, an interrupt, or an I/O event. The Wait call returns a mask indicating which signals were active when the task awoke, allowing the program to determine the cause of the event.

This function is considered "low level".  Its main purpose is to
support multiple higher level functions like Sleep and WaitMem.

Parameters: MASK  
Returns: bit-maks of signals that awoke the task

### USR(8),TASK,SIG_SET - Signal
This function signals a task with the given signals.  If the task
is currently waiting for one or more of these signals, it will be
made ready and a reschedule will occur. If the task is not waiting
for any of these signals, the signals will be posted to the task
for possible later use. A signal may be sent to a task regardless
of whether its running, ready, or waiting.

This function is considered "low level".  Its main purpose is to
support multiple higher level functions like Sleep and WaitMem.

Parameters:  
    task - the task to be signalled  
    signals - the signals to be sent  
Returns: The task's signal set.

### USR(9)


## Notes

There is no error-handling. No parameter checking for valid range.
Not every possible situation has been tested.
Must have an REU enabled with at least 1MB RAM (64KB per Task * 16 Tasks).

I/O isn't protected. Input goes to any runing task.
Each task keeps its own output state.

The border color reflects which current task is running.



## Demos

### Joystick Demo

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

## Planned features

### Features planned for 1st release v1.0:
* Standardize Assembly-Language API (Jump Table)
* Create Assembly-language demos to demonstrate Assembly/BASIC multitasking interopability

### Features planned for 2nd release v2.0:
* Join (Wait for a task to end)
* Better demos
* Cleaned up source code

### Features not planned, but considered:
* Tasks may share BASIC Banks with other tasks
* Task Quantum for Time-Slicing
* Multiple run-time defined IPC Queues
* Other features upon request.
