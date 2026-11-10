10 sys 49152:rem initialize rtos
20 t=usr(1):rem fork, returns task id
25 if t=0 then g=usr(6),1,1:rem task 1 gets its own co-op
30 if t=1 then 100:rem code splits
40 print "hello, world" ti
50 goto 40
100 fori=0to15:poke53281,i:next:goto100
