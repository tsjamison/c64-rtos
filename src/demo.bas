;../release/demo ==0801==

rem *************
rem * rtos demo *
rem *************
rem
rem task0: ui control
rem task1: ui update
rem task2-n: basic busyloop
rem

   10 if z=0 then z=1:load"rtos",8,1
   20 print"{clr}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}"
   30 sys 49152
   40 poke 53281,0
   50 gosub 1000
   60 gosub 2000
   70 for i=1 to usr(13)-1
   80 if t=0 then t=usr(1)
   90 next
  100 on t+1 goto 3000,4000,5000,5000,5000,5000,5000,5000


 1000 hx$="0123456789abcdef"
 1010 cl$="{blk}{wht}{red}{cyn}{pur}{grn}{blu}{yel}"
 1015 dim p%(15),g%(15)
 1020 p%(0)=15:g%(0)=15
 1021 p%(1)=14:g%(1)=0
 1022 p%(2)=0:g%(2)=0
 1023 p%(3)=1:g%(3)=0
 1024 p%(4)=0:g%(4)=1
 1025 p%(5)=0:g%(5)=1
 1026 p%(6)=1:g%(6)=1
 1027 p%(7)=0:g%(7)=2
 1028 p%(8)=0:g%(8)=0
 1029 p%(9)=0:g%(9)=0
 1030 p%(10)=0:g%(10)=0
 1031 p%(11)=0:g%(11)=0
 1032 p%(12)=0:g%(12)=0
 1033 p%(13)=0:g%(13)=0
 1034 p%(14)=0:g%(14)=0
 1035 p%(15)=0:g%(15)=0
 1040 h$(0)="pr (0-15)"
 1041 h$(1)="gp (0-15)"
 1042 h$(2)="bsy (0-255)"
 1043 h$(3)="sleep (0-32767)"
 1044 h$(4)="enqueue"
 1045 h$(5)="dequeue"
 1050 t%(0)=12
 1051 t%(1)=15
 1052 t%(2)=18
 1053 t%(3)=22
 1060 x=0:y=0
 1070 bl%=16384
 1080 sl%=16400
 1085 pokebl%+0,0:pokesl%+0*2,60:pokesl%+0*2+1,0
 1086 pokebl%+1,0:pokesl%+1*2,44:pokesl%+1*2+1,1
 1090 for i=2 to 15
 1100 pokebl%+i,10
 1110 pokesl%+i*2,60
 1120 pokesl%+i*2+1,0
 1130 next
 1140 return

 2000 for i=0 to usr(13)-1
 2010 z=usr(5),i,p%(i)
 2020 z=usr(6),i,g%(i)
 2030 next
 2040 return






 3000 print"{home}"
 3010 for i=0 to usr(13)-1
 3015 printmid$(cl$,i+1,1);
 3020 printmid$(hx$,i+1,1);
 3030 next
 3040 print:print"task status pr gp bsy sleep nq dq"
 3050 for i=0 to usr(13)-1
 3060 print right$("   "+str$(i),4)+" "+st$(usr(14),i);
 3070 print right$("         "+str$(p%(i)),9);
 3080 print right$("  "+str$(g%(i)),3);
 3090 print right$("   "+str$(peek(bl%+i)),4);
 3100 print right$("     "+str$(peek(sl%+i*2)+peek(sl%+i*2+1)*256),6);
 3110 print " nq dq"
 3120 next
 3130 dy%=0:dx%=0:gosub 3400

rem 3070 if y=i and x=1 then print"{rvon}";:t$=str$(p%(i))
rem  3090 if y=i and x=1 then print"{rvof}";
rem  3010 if y=i and x=2 then print"{rvon}";:t$=str$(p%(i))
rem  3030 if y=i and x=2 then print"{rvof}";




 3200 poke 1024+usr(0),(peek(1024+usr(0))+1) and 255
 3210 d%=usr(10)56320,31,31-j%
 3220 j%=31-peek(56320) and 31
 3230 if(j% and16)=16 then gosub 3500:gosub 3400
 3240 if(j% and 1)=1 and y%>0 then dy%=-1
 3250 if(j% and 2)=2 and y%<usr(13)-1 then dy%=1
 3260 if(j% and 4)=4 and x%>0 then dx%=-1
 3270 if(j% and 8)=8 and x%<3 then dx%=1
 3280 if dy%<>0 or dx%<>0 then gosub 3400:dy%=0:dx%=0
 3290 goto 3200


 3400 print"{rvof}";:gosub3440
 3410 y%=y%+dy%:x%=x%+dx%
 3420 print"{rvon}";:gosub3440
 3430 return
 3440 print"{home}{down}{down}";
 3450 for i=0 to y%:print"{down}";:next
 3460 print tab(t%(x%));
 3470 on x%+1 goto 3480, 3481, 3482, 3483
 3480 t$=str$(p%(y%)):print right$(" "+t$,2):return
 3481 t$=str$(g%(y%)):print right$(" "+t$,2):return
 3482 t$=str$(peek(bl%+y%)):print right$("  "+t$,3):return
 3483 t$=str$(peek(sl%+y%*2)+peek(sl%+y%*2+1)*256):print right$("    "+t$,5):return

 3500 p$=h$(x%)+str$(y%)+":"
 3510 gosub 3600
 3520 on x%+1 goto 3530,3531,3532,3533
 3530 p%(y%)=val(t$):z%=usr(5),y%,p%(y%):return
 3531 g%(y%)=val(t$):z%=usr(6),y%,g%(y%):return
 3532 pokebl%+y%,val(t$):return
 3533 pokesl%+y%*2,val(t$)and255:pokesl%+y%*2+1,int(val(t$)/256):return
 3540 return



 3600 z$=t$:t$="                   ":gosub3690:t$=z$
 3610 gosub3690:print"{rvon} {rvof} ";
 3620 get a$:if a$="" then 3620
 3630 if a$="'" or a$="_" then t$=z$:return
 3640 a=asc(a$)
 3650 if a=13 then gosub 3690:print" ";:return
 3660 if a<>20 then t$=t$+a$:goto 3610
 3670 if len(t$)>0 then t$=left$(t$,len(t$)-1)
 3680 goto 3610
 3690 print"{home}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}{down}"+p$+" "+t$;:return

 4000 st$(0)="-----"
 4002 st$(2)=" run "
 4003 st$(3)="ready"
 4004 st$(4)="sleep"
 4010 poke 1024+usr(0),(peek(1024+usr(0))+1) and 255
 4020 print"{home}{down}{down}"
 4030 for i=0 to usr(13)-1
 4040 print tab(5)+st$(usr(14),i)
 4050 next
 4060 z=usr(9),peek(sl%+t*2)+peek(sl%+t*2+1)*256
 4070 goto 4010

 5000 for i=0 to peek(bl%+t)
 5010 poke 1024+usr(0),i
 5020 next
 5030 z=usr(9),peek(sl%+t*2)+peek(sl%+t*2+1)*256
 5030 goto 5000
 9999 end












