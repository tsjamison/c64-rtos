10 sys 49152:rem initialize rtos
20 t=usr(1):rem fork: new task's id to the parent, 255 to the new task
25 if t<>255 then g=usr(6),t,t:rem the new task gets its own co-op
30 if t=255 then 100:rem code splits
40 print "hello, world" ti
50 goto 40
100 fori=0to15:poke53281,i:next:goto100
