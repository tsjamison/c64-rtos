0 rem initialize music
5 if z=0 then z=1:load"rtos",8,1

60 diml%(10),h%(10):i=1:s=54272
70 reada:ifa<>-1thenh%(i)=a/256:l%(i)=a-h%(i)*256:i=i+1:goto70
80 dimn%(30),d%(30):i=0
90 reada,b:ifa<>-1thenn%(i)=a:d%(i)=b:i=i+1:goto90
95 n=i

100 v=53248 : rem start of  display chip
110 poke v+21,4 : rem enable sprite 2
120 poke 2042,13 : rem sprite 2 data from 13th blk
130 for r = 0 to 62: read q : poke 832+r,q: next

200 dx=32768:dy=32769
210 poke dx,0:poke dy,0
220 poke v+4,128: poke v+5,100

900 rem initialize rtos
910 sys 49152
921 p=usr(5),1,3:rem task1 priority=3
922 p=usr(5),2,2:rem task2 priority=2
923 p=usr(5),3,1:rem task3 priority=1
931 c=usr(6),1,1:rem task1 coop=1
932 c=usr(6),2,2:rem task2 coop=0
933 c=usr(6),3,3:rem task3 coop=0
941 t=usr(1):ift=1then1000
942 t=usr(1):ift=2then2000
943 t=usr(1):ift=3then3000
950 end



1000 rem play music
1010 pokes+24,15:pokes+6,240
1020 if i=30 then i=0
1030 pokes,l%(n%(i)):pokes+1,h%(n%(i)):pokes+4,33
1040 d=usr(9),d%(i):pokes+4,32:i=i+1:goto1020
1050 pokes+24,0:rem stop music

2000 rem show sprite
2050 pokev+4,peek(v+4)+peek(dx)and255
2060 pokev+5,peek(v+5)+peek(dy)and255
2070 z=usr(9),2
2080 goto 2050

3000 rem read joystick
3010 d=usr(10)56320,31,31-j
3020 j=31-peek(56320)and31
3030 if(jand1)=1thenpokedy,255
3040 if(jand2)=2thenpokedy,1
3045 if(jand3)=0thenpokedy,0
3050 if(jand4)=4thenpokedx,255
3060 if(jand8)=8thenpokedx,1
3065 if(jand12)=0thenpokedx,0
3070 goto 3010


60010 data2195,2463,2765,2930,3288,3691,4143,4389,-1
60020 data1,10,3,10,4,10,5,50,1,10,3,10,4,10,5,50
60030 data1,10,3,10,4,10,5,20,3,20,1,20,3,20,2,60
60040 data3,10,2,10,1,40,3,20,5,30,4,50,3,10,4,10
60050 data5,20,3,20,1,20,2,20,1,50,-1,-1

61010 data 0,127,0,1,255,192,3,255,224,3,231,224
61020 data 7,217,240,7,223,240,7,217,240,3,231,224
61030 data 3,255,224,3,255,224,2,255,160,1,127,64
61040 data 1,62,64,0,156,128,0,156,128,0,73,0
61050 data 0,73,0,0,62,0,0,62,0,0,62,0,0,28,0
