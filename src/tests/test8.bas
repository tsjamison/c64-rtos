1 rem rtos test 8: re-pick and co-op owners
2 rem part 1 runs task 0 alone, so a hang
3 rem there is a scheduler regression
10 if z=0 then z=1:load"rtos",8,1
20 sys 49152
30 gosub 9900
40 print"test 8: re-pick and co-op owners":print
50 poke 56335,peek(56335)and 127
60 poke 56334,(peek(56334)and 127)or 128*(peek(678)and 1)
70 poke 56331,0:poke 56330,0:poke 56329,0:poke 56328,0
100 rem part 1: task 0 is the only task
110 gosub 9700:t0=tt:s=usr(9),30:gosub 9700:dt=tt-t0
120 n$="lone task wakes from usr(9),30"
130 ok=s=64 and dt>=4 and dt<=7:gosub 9000
140 s=usr(14),0:n$="re-picked after sleep: running (2)":ok=s=2:gosub 9000
150 q=usr(9),0:s=usr(14),0:n$="re-picked after yield: running (2)"
160 ok=s=2:gosub 9000
200 rem part 2: a co-op mate must not cut in after a lone yield
210 gosub 9600:c=nx:q=usr(6),c,0:t=usr(1):if usr(0)<>0 then 5000
220 q=usr(9),5:ws=4:gosub 9500
230 q=usr(9),0:r=usr(8),c,1:s=usr(14),c:g=peek(mb+1)
240 n$="mate co-opted (7) after lone yield":ok=s=7:gosub 9000
250 n$="mate waits until task 0 waits":ok=g=255:gosub 9000
260 q=usr(9),5:wa=mb+1:gosub 9400:ws=0:gosub 9500
300 rem part 3: co-op owners, with a keeper
310 gosub 9100
320 gosub 9600:a=nx:r=1:t=usr(1):if usr(0)<>0 then 5100
330 wa=mb+11:gosub 9400
340 gosub 9600:b=nx:q=usr(6),b,a:r=2:t=usr(1):if usr(0)<>0 then 5100
350 q=usr(9),30:s=usr(14),b:s2=usr(14),a
360 n$="busy owner blocks its mate (7)":ok=s=7 and peek(mb+12)=255
370 gosub 9000
380 n$="pre-empted owner shows 8":ok=s2=8:gosub 9000
390 poke mb+20,1:wa=mb+12:gosub 9400
400 n$="owner ending frees its co-op":ok=peek(mb+12)<>255:gosub 9000
410 poke mb+21,1:c=b:ws=0:gosub 9500
500 rem part 4: moving the owner to another co-op
510 gosub 9600:c=nx:r=3:t=usr(1):if usr(0)<>0 then 5100
520 wa=mb+13:gosub 9400
530 gosub 9600:d=nx:q=usr(6),d,c:r=4:t=usr(1):if usr(0)<>0 then 5100
540 q=usr(9),30:s=usr(14),d
550 n$="new mate blocked (7)":ok=s=7 and peek(mb+14)=255:gosub 9000
560 q=usr(6),c,14:wa=mb+14:gosub 9400
570 n$="moving the owner frees old co-op":ok=peek(mb+14)<>255:gosub 9000
580 poke mb+13,0:q=usr(9),30
590 n$="moved owner still runs":ok=peek(mb+13)=1:gosub 9000
600 poke mb+22,1:poke mb+23,1:ws=0:gosub 9500:c=d:gosub 9500
900 goto 9300
5000 r=usr(7),1:poke mb+1,1:q=usr(4)
5100 poke mb+10+r,1:if peek(mb+19+r)=255 then 5100
5110 q=usr(4)
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
