1 rem rtos test 6: per-task queues
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
180 a=usr(11)"abcd",c:a=usr(11)"efghij",c:poke mb+3,1:wa=mb+5:gosub 9400
190 n$="first message abcd":ok=peek(mb+4)=1:gosub 9000
200 n$="second message efghij":ok=peek(mb+5)=1:gosub 9000
210 ws=0:gosub 9500
220 a=usr(11)"x",0:a=usr(11)"hello",c:b$=usr(12)
230 n$="each task reads only its own queue":ok=b$="x":gosub 9000
300 rem two producers each send ten 10-byte messages. a message
302 rem and its length byte take 11 of 16 bytes, so writers wait
310 for k=1 to 2:gosub 9600
315 t=usr(1):gosub 9640:if usr(0)<>0 then 5100
318 next
320 na=0:nk=0:nb=0:for j=1 to 20:m$=usr(12)
330 if m$="abcdefghij" then na=na+1:goto 345
335 if m$="klmnopqrst" then nk=nk+1:goto 345
340 nb=nb+1
345 next
350 n$="20 whole messages, 10 from each":ok=na=10 and nk=10 and nb=0
355 gosub 9000
430 wa=mb+11:gosub 9400:wa=mb+12:gosub 9400
440 n$="every usr(11) returned 10":ok=peek(mb+13)=10 and peek(mb+14)=10
450 gosub 9000
500 rem a writer to a full queue gets -1 when the reader ends
510 gosub 9600:c=nx:t=usr(1):gosub 9640:if usr(0)<>0 then 5200
520 a=usr(11)"abcdefghijklmno",c:b=usr(11)"x",c
530 n$="full queue, reader ends: -1":ok=a=15 and b=-1:gosub 9000
600 rem an empty message wakes a waiting reader
610 gosub 9600:c=nx:t=usr(1):gosub 9640:if usr(0)<>0 then 5300
620 ws=4:gosub 9500:a=usr(11)"",c:wa=mb+20:gosub 9400
630 n$="empty message wakes a waiting reader":ok=a=0 and peek(mb+20)=1
640 gosub 9000:ws=0:gosub 9500
900 goto 9300
5000 a$=usr(12):poke mb+1,len(a$):poke mb+2,-(a$="hello")
5010 if peek(mb+3)=255 then q=usr(9),1:goto 5010
5020 a$=usr(12):poke mb+4,-(a$="abcd")
5030 a$=usr(12):poke mb+5,-(a$="efghij")
5040 q=usr(4)
5100 a$=mid$("abcdefghijklmnopqrst",k*10-9,10):n=0
5110 for j=1 to 10:q=usr(11)a$,0:n=n-(q=10):next
5120 poke mb+12+k,n:poke mb+10+k,1:q=usr(4)
5200 q=usr(9),30:q=usr(4)
5300 m$=usr(12):poke mb+20,-(m$=""):q=usr(4)
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
