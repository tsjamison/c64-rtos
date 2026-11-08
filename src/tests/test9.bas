1 rem rtos test 9: open-issue checks
2 rem forbid, slot reuse, queue edge cases.
3 rem the last check may overwrite strings
4 rem while usr(12),0 still overruns
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 9: forbid, slot reuse, queue":print
100 rem forbid across a wait. no keeper here:
101 rem a busy task would hog the cpu
110 gosub 9600:c=nx:t=usr(1):if usr(0)<>0 then 5000
120 f=usr(2):poke mb+1,1:q=usr(9),30:f=usr(3)
130 wa=mb+2:gosub 9400
140 n$="usr(2) count doesn't leak to others":ok=peek(mb+2)=1:gosub 9000
150 ws=0:gosub 9500
200 rem slot reuse: old timer, signal, priority
210 gosub 9100
220 gosub 9600:x=nx:t=usr(1):if usr(0)<>0 then 5100
230 c=x:ws=4:gosub 9500:q=usr(5),x,3:r=usr(8),x,2
240 q=usr(4),x
250 gosub 9650:y=nx:t=usr(1):if usr(0)<>0 then 5200
260 n$="new task reuses slot"+str$(x):ok=y=x:gosub 9000
270 p=usr(5),y,0:n$="new task doesn't get old priority":ok=p<>3
280 gosub 9000
290 q=usr(9),180:s=usr(14),y
300 n$="no stale timer or signal wakes it":ok=s=4 and peek(mb+3)=255
310 gosub 9000
320 r=usr(8),y,3:c=y:ws=0:gosub 9500
400 rem queue signal with an empty queue
410 gosub 9600:c=nx:t=usr(1):if usr(0)<>0 then 5300
420 ws=4:gosub 9500:r=usr(8),c,16:q=usr(9),10:s=usr(14),c
430 n$="woken on empty queue, waits again":ok=s=4 and peek(mb+4)=255
440 gosub 9000:ok=0
450 if s=4 then a=usr(11)"hi",c:wa=mb+4:gosub 9400:ok=peek(mb+4)=1
460 n$="then gets hi":gosub 9000:ws=0:gosub 9500
500 rem two waiting usr(12) calls keep their own lengths
510 gosub 9600:a=nx:r=5:t=usr(1):if usr(0)<>0 then 5400
520 c=a:ws=4:gosub 9500
530 gosub 9600:b=nx:r=6:t=usr(1):if usr(0)<>0 then 5400
540 c=b:ws=4:gosub 9500
550 q=usr(11)"abcdefghij",a:wa=mb+5:gosub 9400
560 n$="first waiter gets all 10 bytes":ok=peek(mb+5)=10:gosub 9000
570 q=usr(11)"xy",b:wa=mb+6:gosub 9400
580 n$="second waiter gets its xy":ok=peek(mb+6)=1:gosub 9000
600 rem last: usr(12),0
610 a$="sentinel"+"":q=usr(11)"x",0:b$=usr(12),0
620 n$="usr(12),0 returns empty string":ok=len(b$)=0:gosub 9000
630 n$="usr(12),0 leaves strings alone":ok=a$="sentinel":gosub 9000
900 goto 9300
5000 if peek(mb+1)=255 then q=usr(9),1:goto 5000
5010 a=usr(2):b=usr(3):poke mb+2,a:q=usr(4)
5100 q=usr(9),120:goto 5100
5200 r=usr(7),66:poke mb+3,r:r=usr(7),1:q=usr(4)
5300 a$=usr(12),5:poke mb+4,-(a$="hi"):q=usr(4)
5400 if r=5 then a$=usr(12),10:poke mb+5,len(a$):q=usr(4)
5410 a$=usr(12),2:poke mb+6,-(a$="xy"):q=usr(4)
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
