1 rem rtos test 4: wait and signal
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 4: usr(7) wait, usr(8) signal":print
100 gosub 9100
110 gosub 9600:c=nx:t=usr(1):if usr(0)<>0 then 5000
120 ws=4:gosub 9500
130 n$="usr(7),3 puts task in wait (4)":ok=s=4:gosub 9000
140 r=usr(8),c,4:q=usr(9),10:s=usr(14),c
150 n$="signal outside mask doesn't wake":ok=s=4 and peek(mb+1)=255
160 gosub 9000
170 r=usr(8),c,2:wa=mb+1:gosub 9400
180 n$="usr(8) returns task's signals":ok=(r and 4)=4:gosub 9000
190 n$="usr(7),3 woken by 2 returns 2":ok=peek(mb+1)=2:gosub 9000
200 r=usr(8),c,1:poke mb+2,1:wa=mb+3:gosub 9400
210 n$="pending signal ends usr(7) at once":ok=peek(mb+3)=1:gosub 9000
220 wa=mb+4:gosub 9400
230 n$="unmatched signal stays pending":ok=peek(mb+4)=4:gosub 9000
240 wa=mb+5:gosub 9400
250 n$="usr(7),0 yields, returns 0":ok=peek(mb+5)=0:gosub 9000
300 ws=4:gosub 9500:r=usr(8),c,8:wa=mb+6:gosub 9400
310 n$="app signal 8 wakes usr(7),8":ok=peek(mb+6)=8:gosub 9000
320 ws=0:gosub 9500
900 goto 9300
5000 r=usr(7),3:poke mb+1,r
5010 if peek(mb+2)=255 then q=usr(9),1:goto 5010
5020 r=usr(7),1:poke mb+3,r
5030 r=usr(7),4:poke mb+4,r
5040 r=usr(7),0:poke mb+5,r
5050 r=usr(7),8:poke mb+6,r
5060 q=usr(4)
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
