1 rem rtos known issues: each choice shows
2 rem one issue that can't be checked safely
3 rem by a test. most hang or crash the c64
4 rem while the issue is open: reset after.
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900:print
40 print"known issues"
50 print" 1 fork with no free slot"
60 print" 2 usr(200): bad usr number"
70 print" 3 usr(8),200,1: bad task id"
80 print" 4 usr(6),0,16: bad co-op (fixed)"
90 print" 5 idle screen blanking"
95 input"which";k:print:on k goto 1000,2000,3000,4000,5000:end
1000 print"forking until the slots run out."
1010 print"dead keyboard after the error"
1020 print"= still open."
1030 for k=1 to mt:t=usr(1):if usr(0)<>0 then 1100
1040 print"forked";k:next
1100 r=usr(7),128:goto 1100
2000 print"fixed: ?illegal quantity error."
2010 print"open: crash, hang or garbage."
2020 q=usr(200):print"no error: still open":end
3000 print"fixed: ?illegal quantity error."
3010 print"open: prints no error (and has"
3020 print"written past the rtos arrays)."
3030 q=usr(8),200,1:print"no error: still open":end
4000 print"expect ?illegal quantity error."
4010 q=usr(6),0,16:print"no error: check failed":end
5000 print"task 0 sleeps 3s with no other task."
5010 print"screen goes blank = still open."
5020 q=usr(9),180:print"done":end
8999 rem ---- shared test harness ----
9000 if ok then ps=ps+1:print"pass ";n$:return
9010 fl=fl+1:print"{rvon}fail{rvof} ";n$:return
9100 rem fork a busy keeper task so a sleeping task always has
9101 rem another task to switch to (avoids open issue 1)
9110 gosub 9600:kp=nx:t=usr(1):gosub 9640:if usr(0)<>0 then 9150
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
9600 rem nx = slot the next fork will use. cn = the co-op 9640
9601 rem gives it: its own by default, so new tasks are pre-emptive
9610 gosub 9650:if nx=0 then print"no free task slot":end
9630 cn=nx:return
9640 rem after a fork the child has the parent's co-op and priority.
9641 rem the parent moves it to co-op cn, priority 0. the child can't
9642 rem run before that: it is in the parent's co-op
9645 if usr(0)=0 then q=usr(6),nx,cn:q=usr(5),nx,0
9646 return
9650 rem nx = slot the next fork will use, settings untouched
9660 nx=0:for i=1 to mt-1:s=usr(14),i:if s=0 and nx=0 then nx=i
9670 next:return
9700 rem tt = tod clock in tenths of a second
9710 h=peek(56331):m=peek(56330):s1=peek(56329):t1=peek(56328)
9720 tt=(int(m/16)*10+(m and 15))*600+(int(s1/16)*10+(s1 and 15))*10
9730 tt=tt+(t1 and 15):return
9900 rem init. mb = mailbox at $cf00, shared by all tasks
9910 mt=usr(13):mb=52992:ps=0:fl=0:kp=0
9920 for i=0 to 63:poke mb+i,255:next:return
