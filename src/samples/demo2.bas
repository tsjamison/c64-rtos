10 sys 49152:rem initialize rtos
20 print "{clr}"
30 z=usr(5),0,0:z=usr(6),0,0
100 for i=1 to 7:c=usr(1):if c=255 then i=99:rem new task: stop forking
105 next
106 t=usr(0)
110 if t=0 then for i=1 to 7:z=usr(6),i,i:next:rem own co-ops
200 print "{home}"
210 for i=0 to t:print"{down}";:next
220 print t "task" ti
230 goto 200
