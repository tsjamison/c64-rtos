1 rem rtos test 6: queue between tasks
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 6: usr(11)/usr(12) queue":print
100 gosub 9100
110 gosub 9600:c=nx:t=usr(1):gosub 9640:if usr(0)<>0 then 5000
120 ws=4:gosub 9500
130 n$="usr(12) waits on empty queue":ok=s=4:gosub 9000
140 a=usr(11)"hello",c:wa=mb+1:gosub 9400
150 n$="usr(11) hello returns 5":ok=a=5:gosub 9000
160 n$="waiting task gets hello":ok=peek(mb+1)=5 and peek(mb+2)=1
170 gosub 9000
180 a=usr(11)"abcdefghij",c:poke mb+3,1:wa=mb+5:gosub 9400
190 n$="usr(12),4 takes abcd":ok=peek(mb+4)=1:gosub 9000
200 n$="usr(12),10 takes the rest":ok=peek(mb+5)=1:gosub 9000
210 ws=0:gosub 9500
300 for k=1 to 2:gosub 9600:p$=chr$(64+k)
305 t=usr(1):gosub 9640:if usr(0)<>0 then 5100
310 next
320 wa=mb+11:gosub 9400:wa=mb+12:gosub 9400
330 b$=usr(12),255
340 n$="two producers: 200 bytes":ok=len(b$)=200:gosub 9000
350 ok=-1:na=0
360 for k=1 to 200 step 10:c$=mid$(b$,k,10):d$=left$(c$,1)
370 e$=d$+d$+d$+d$+d$+d$+d$+d$+d$+d$:if c$<>e$ then ok=0
380 if d$="a" then na=na+1
390 next
400 n$="each usr(11) arrives in one piece":gosub 9000
410 n$="10 from each producer":ok=na=10:gosub 9000
900 goto 9300
5000 a$=usr(12),10:poke mb+1,len(a$):poke mb+2,-(a$="hello")
5010 if peek(mb+3)=255 then q=usr(9),1:goto 5010
5020 a$=usr(12),4:poke mb+4,-(a$="abcd")
5030 a$=usr(12),10:poke mb+5,-(a$="efghij")
5040 q=usr(4)
5100 a$=p$+p$+p$+p$+p$+p$+p$+p$+p$+p$
5110 for j=1 to 10:q=usr(11)a$,0:next
5120 poke mb+10+k,1:q=usr(4)
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
