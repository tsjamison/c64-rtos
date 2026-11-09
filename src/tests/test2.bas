1 rem rtos test 2: fork, end task, state
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 2: usr(1) fork, usr(4) end":print
100 gosub 9100
110 n$="keeper started as task"+str$(kp):ok=kp>0:gosub 9000
120 s=usr(14),kp:n$="keeper is ready/pre-empted":ok=s=3 or s=8:gosub 9000
200 sv=42:gosub 9600:c=nx:c1=nx:t=usr(1):gosub 9640:if usr(0)<>0 then 5000
210 n$="usr(1) returns 0 to the parent":ok=t=0:gosub 9000
220 wa=mb+1:gosub 9400
230 n$="child is task"+str$(c):ok=peek(mb+1)=c:gosub 9000
240 n$="child's usr(1) is its own id":ok=peek(mb+2)=1:gosub 9000
250 n$="child has parent's variables":ok=peek(mb+3)=1:gosub 9000
260 s=usr(14),c:n$="child is ready/pre-empted":ok=s=3 or s=8:gosub 9000
270 poke mb+4,1:ws=0:gosub 9500
280 n$="usr(4) ends the calling task":ok=s=0:gosub 9000
300 gosub 9600:c=nx:t=usr(1):gosub 9640:if usr(0)<>0 then 5100
310 wa=mb+5:gosub 9400:q=usr(4),c:s=usr(14),c
320 n$="usr(4),task ends another task":ok=s=0:gosub 9000
400 gosub 9600:t=usr(1):gosub 9640:if usr(0)<>0 then 5200
410 wa=mb+6:gosub 9400
420 n$="fork reuses a freed slot":ok=peek(mb+6)=c1:gosub 9000
430 c=c1:ws=0:gosub 9500
500 rem a child starts with its parent's priority and co-op
510 q=usr(5),0,1:q=usr(6),0,5:gosub 9650:c=nx
520 t=usr(1):if usr(0)<>0 then 5300
530 p=usr(5),c,0:o=usr(6),c,c:q=usr(5),0,0:q=usr(6),0,0
540 n$="child gets parent's priority (1)":ok=p=1:gosub 9000
550 n$="child gets parent's co-op (5)":ok=o=5:gosub 9000
560 ws=0:gosub 9500
900 goto 9300
5000 poke mb+1,usr(0):poke mb+2,-(t=usr(0)):poke mb+3,-(sv=42)
5010 if peek(mb+4)=255 then 5010
5020 q=usr(4)
5100 poke mb+5,usr(0)
5110 goto 5110
5200 poke mb+6,usr(0):q=usr(4)
5300 q=usr(4)
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
