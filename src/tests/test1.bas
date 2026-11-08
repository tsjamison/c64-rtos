1 rem rtos test 1: single-task basics
2 rem only calls that never wait, so
3 rem no other task is needed
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 1: single-task basics":print
100 t=usr(0):n$="usr(0) first task is 0":ok=t=0:gosub 9000
110 n$="usr(13) max tasks is"+str$(mt):ok=mt>=2 and mt<=16:gosub 9000
120 s=usr(14),0:n$="usr(14) task 0 is running (2)":ok=s=2:gosub 9000
130 s=usr(14),1:n$="usr(14) unused slot is 0":ok=s=0:gosub 9000
200 a=usr(2):b=usr(2):c=usr(3):d=usr(3):e=usr(3)
210 n$="usr(2)/usr(3) nest 1,2,1,0":ok=a=1 and b=2 and c=1 and d=0
220 gosub 9000
230 n$="extra usr(3) stays at 0":ok=e=0:gosub 9000
300 a=usr(5),0,3:b=usr(5),0,0
310 n$="usr(5) returns old priority":ok=a=0 and b=3:gosub 9000
320 a=usr(6),0,7:b=usr(6),0,0
330 n$="usr(6) returns old co-op":ok=a=0 and b=7:gosub 9000
400 a=usr(8),0,1:b=usr(8),0,2
410 n$="usr(8) returns signal set":ok=a=1 and b=3:gosub 9000
500 a=usr(11)"abc",0:n$="usr(11) abc returns 3":ok=a=3:gosub 9000
510 s=usr(8),0,0:n$="usr(11) posts signal 16":ok=(s and 16)=16:gosub 9000
520 b$=usr(12),2:n$="usr(12),2 returns ab":ok=b$="ab":gosub 9000
530 b$=usr(12),5:n$="usr(12),5 returns c":ok=b$="c":gosub 9000
540 s=usr(8),0,0:n$="usr(12) clears signal 16":ok=(s and 16)=0:gosub 9000
550 a=usr(11)"",0:n$="usr(11) empty string is 0":ok=a=0:gosub 9000
600 b$="":for k=1 to 200:b$=b$+chr$(65+k-int(k/26)*26):next
610 a=usr(11)b$,0:c=usr(11)b$,0
620 n$="queue holds 255 (200+55)":ok=a=200 and c=55:gosub 9000
630 c$=usr(12),255:n$="usr(12),255 gets 255":ok=len(c$)=255:gosub 9000
640 ok=left$(c$,200)=b$ and right$(c$,55)=left$(b$,55)
650 n$="queued bytes come out in order":gosub 9000
900 goto 9300
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
