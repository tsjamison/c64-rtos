10 rem ---==* joystick demo *==---
11 rem this demonstrates waitm
12 rem it waits for the joystick
13 rem to change then returns
14 rem what changed
15 rem this loops forever
20 rem ===========================
21 rem load rtos
30 ifz=0thenz=1:load"rtos",8,1
40 sys 49152
50 rem ===========================
51 rem fork a new task
52 rem set task 1 to priority 1
53 rem set task 1 to coop 1
54 rem idle task loops forever
60 t=usr(1)
70 if t=0 then z=usr(5),1,1:x=usr(6),1,1
80 if t=0 then 80
90 print"use joystick port 2"
100 d=usr(10)56320,31,31-j
110 j=31-peek(56320) and 31
120 printd,j
130 goto100
