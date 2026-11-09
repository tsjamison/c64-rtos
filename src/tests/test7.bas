1 rem rtos test 7: priority, co-op, forbid
2 rem busy tasks poke mb+r to show they ran
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 7: priority, co-op, forbid":print
100 gosub 9100
110 q=usr(5),0,2
120 gosub 9600:a=nx:r=1:t=usr(1):gosub 9640:if usr(0)<>0 then 5000
130 gosub 9600:b=nx:r=2:t=usr(1):gosub 9640:if usr(0)<>0 then 5000
200 q=usr(5),a,1:poke mb+1,0:poke mb+2,0:k0=peek(mb+62)
210 q=usr(9),60
220 n$="pri 1 task runs while pri 2 sleeps":ok=peek(mb+1)=1:gosub 9000
230 ok=peek(mb+2)=0 and peek(mb+62)=k0
240 n$="busy pri 1 task starves pri 0":gosub 9000
250 q=usr(5),a,0
300 poke mb+1,0:poke mb+2,0:q=usr(9),60
310 n$="equal pri, own co-ops: both run"
320 ok=peek(mb+1)=1 and peek(mb+2)=1:gosub 9000
400 gosub 9600:c=nx:r=3:t=usr(1):gosub 9640:if usr(0)<>0 then 5000
410 gosub 9600:d=nx:cn=c:r=4:t=usr(1):gosub 9640:if usr(0)<>0 then 5000
420 poke mb+3,0:poke mb+4,0:q=usr(9),60
430 n$="same co-op: only one busy task runs"
440 ok=peek(mb+3)+peek(mb+4)=1:gosub 9000
450 s=usr(14),c:s2=usr(14),d
460 n$="the other is co-opted (7)":ok=s=7 or s2=7:gosub 9000
500 q=usr(5),0,0:f=usr(2):poke mb+1,0
510 for k=1 to 500:next:g=peek(mb+1):f=usr(3)
520 n$="usr(2) stops pre-emption":ok=g=0:gosub 9000
530 q=usr(9),30:n$="usr(3) restores it":ok=peek(mb+1)=1:gosub 9000
600 q=usr(4),a:q=usr(4),b:q=usr(4),c:q=usr(4),d
900 goto 9300
5000 poke mb+r,1:goto 5000
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
