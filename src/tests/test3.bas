1 rem rtos test 3: sleep timing
2 rem times sleeps with the cia1 tod
3 rem clock, which all tasks share
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 3: usr(9) sleep":print
50 poke 56335,peek(56335)and 127
60 poke 56334,(peek(56334)and 127)or 128*(peek(678)and 1)
70 poke 56331,0:poke 56330,0:poke 56329,0:poke 56328,0
100 gosub 9100
110 gosub 9700:t0=tt:s=usr(9),60:gosub 9700:dt=tt-t0
120 n$="usr(9),60 took"+str$(dt/10)+"s":ok=dt>=8 and dt<=13:gosub 9000
130 n$="usr(9) returns timer signal 64":ok=s=64:gosub 9000
140 gosub 9700:t0=tt:s=usr(9),300:gosub 9700:dt=tt-t0
150 n$="usr(9),300 took"+str$(dt/10)+"s":ok=dt>=48 and dt<=55
160 gosub 9000
200 a=peek(mb+62):q=usr(9),30:b=peek(mb+62)
210 n$="other tasks run during a sleep":ok=a<>b:gosub 9000
300 gosub 9700:t0=tt:gosub 9700:b=tt-t0:rem cost of 2 clock reads
305 gosub 9700:t0=tt:s=usr(9),0:gosub 9700:dt=tt-t0
310 n$="usr(9),0 yields, returns 0":ok=s=0 and dt<=b+5:gosub 9000
400 gosub 9600:c=nx:t=usr(1):if usr(0)<>0 then 5000
410 s=usr(9),60
420 n$="shorter sleep in other task ends 1st":ok=peek(mb+1)=1
430 gosub 9000:ws=0:gosub 9500
900 goto 9300
5000 q=usr(9),30:poke mb+1,1:q=usr(4)
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
9610 gosub 9650:if nx=0 then print"no free task slot":end
9630 q=usr(6),nx,nx:q=usr(5),nx,0:return
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
