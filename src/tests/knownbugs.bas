1 rem rtos known issues: each choice
2 rem reproduces one open issue from
3 rem the analysis doc. 1, 3 and 4 hang
4 rem the c64 while the issue is open.
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900:print
40 print"known issues"
50 print" 1 lone task never wakes from sleep"
60 print" 2 usr(12),0 overwrites strings"
70 print" 3 usr(4) strands a co-op mate"
80 print" 4 fork with no free slot"
90 input"which";k:print:on k goto 1000,2000,3000,4000:end
1000 print"sleeping 1s with no other task."
1010 print"hang = issue 1 still open."
1020 q=usr(9),60:print"done: issue 1 is fixed":end
2000 a$="sentinel"+"":q=usr(11)"x",0:b$=usr(12),0
2010 if a$="sentinel" then print"a$ intact: issue 2 is fixed":end
2020 print"a$ overwritten: issue 2 still open":end
3000 print"parent sleeps while a child in its"
3010 print"co-op runs, then the child ends."
3020 print"hang = issue 3 still open."
3030 gosub 9600:q=usr(6),nx,0:t=usr(1):if usr(0)<>0 then 3100
3040 q=usr(9),30:print"done: issue 3 is fixed":end
3100 for k=1 to 2000:next:q=usr(4)
4000 print"forking until the slots run out."
4010 print"dead keyboard after the error"
4020 print"= issue 4 still open."
4030 for k=1 to mt:t=usr(1):if usr(0)<>0 then 4100
4040 print"forked";k:next
4100 r=usr(7),128:goto 4100
8999 rem ---- shared test harness ----
9000 if ok then ps=ps+1:print"pass ";n$:return
9010 fl=fl+1:print"{rvon}fail{rvof} ";n$:return
9100 rem fork a busy keeper task so a sleeping task always has
9101 rem another task to switch to (avoids open issue 1)
9110 gosub 9600:kp=nx:t=usr(1):if usr(0)<>0 then 9150
9120 return
9150 poke mb+62,(peek(mb+62)+1)and 255:goto 9150
9300 rem end: remove keeper, print summary
9310 if kp then q=usr(4),kp
9320 print:print ps;"passed,";fl;"failed":end
9400 rem wait until peek(wa)<>255, about 5s max
9410 w=0
9420 if peek(wa)<>255 then return
9430 w=w+1:if w>300 then print"timeout at";wa-mb:return
9440 q=usr(9),1:goto 9420
9500 rem wait until task c is in state ws, about 5s max
9510 w=0
9520 s=usr(14),c:if s=ws then return
9530 w=w+1:if w>300 then return
9540 q=usr(9),1:goto 9520
9600 rem nx = slot the next fork will use. give it its own
9601 rem co-op and priority 0 so new tasks are pre-emptive
9610 nx=0:for i=1 to mt-1:s=usr(14),i:if s=0 and nx=0 then nx=i
9620 next:if nx=0 then print"no free task slot":end
9630 q=usr(6),nx,nx:q=usr(5),nx,0:return
9700 rem tt = tod clock in tenths of a second
9710 h=peek(56331):m=peek(56330):s1=peek(56329):t1=peek(56328)
9720 tt=(int(m/16)*10+(m and 15))*600+(int(s1/16)*10+(s1 and 15))*10
9730 tt=tt+(t1 and 15):return
9900 rem init. mb = mailbox at $cf00, shared by all tasks
9910 mt=usr(13):mb=52992:ps=0:fl=0:kp=0
9920 for i=0 to 63:poke mb+i,255:next:return
