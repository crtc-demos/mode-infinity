#!/bin/sh
set -e
#./fontconv -o font.s 16x16.png
#pasta font.s -o font
./fontconv 36fontb.png -o 36font.s
cat >> 36font.s << EOF
char_columns
S:
_a:	.byte 00,01,02			       ; A
b:	.byte 03,04,05			       ; B
c:	.byte 06,07,08			       ; C
d:	.byte 03,07,08			       ; D
e:	.byte 03,04,04			       ; E
f:	.byte 03,01,01			       ; F
g:	.byte 06,04,10			       ; G
h:	.byte 03,11,03			       ; H
i:	.byte 03			       ; I
j:	.byte 14,13,12			       ; J
k:	.byte 03,11,15			       ; K
l:	.byte 03,13,13			       ; L
m:	.byte 03,16,03,16,02 		       ; M
n:	.byte 03,16,02			       ; N
o:	.byte 06,07,09			       ; O
p:	.byte 03,02,17			       ; P
q:	.byte 06,07,02,13		       ; Q
r:	.byte 03,01,18			       ; R
s:	.byte 34,04,31			       ; S
t:	.byte 16,03,16			       ; T
u:	.byte 21,13,12			       ; U
v:	.byte 22,23,03			       ; V
w:	.byte 21,13,04,13,12 		       ; W
_x:	.byte 24,11,15 			       ; X
_y:	.byte 26,25,12			       ; Y
z:	.byte 27,04,28			       ; Z
n0:	.byte 06,07,08			       ; 0
n1:	.byte 16,03  			       ; 1
n2:	.byte 27,04,29			       ; 2
n3:	.byte 04,04,05			       ; 3
n4:	.byte 30,11,03			       ; 4
n5:	.byte 26,05,29			       ; 5
n6:	.byte 06,04,31			       ; 6
n7:	.byte 16,16,03			       ; 7
n8:	.byte 33,04,32			       ; 8
n9:	.byte 34,04,09			       ; 9
ck:	.byte 25			       ; :
cd:	.byte 13			       ; .
cc:	.byte 35			       ; ,
ch:	.byte 11			       ; -
spc:	.byte 36			       ; <space>
char_lens
	.byte 3,3,3,3,3,3,3,3,1
	.byte 3,3,3,5,3,3,3,4,3,3,3,3,3
	.byte 5,3,3,3,3,2,3,3,3,3,3,3,3,3,1,1,1,1,1
char_starts:
	.byte _a-S
	.byte b-S
	.byte c-S
	.byte d-S
	.byte e-S
	.byte f-S
	.byte g-S
	.byte h-S
	.byte i-S
	.byte j-S
	.byte k-S
	.byte l-S
	.byte m-S
	.byte n-S
	.byte o-S
	.byte p-S
	.byte q-S
	.byte r-S
	.byte s-S
	.byte t-S
	.byte u-S
	.byte v-S
	.byte w-S
	.byte _x-S
	.byte _y-S
	.byte z-S
	.byte n0-S
	.byte n1-S
	.byte n2-S
	.byte n3-S
	.byte n4-S
	.byte n5-S
	.byte n6-S
	.byte n7-S
	.byte n8-S
	.byte n9-S
	.byte ck-S
	.byte cd-S
	.byte cc-S
	.byte ch-S
	.byte spc-S
EOF

./fontconv 64font4.png -o 64font.s
cat >> 64font.s << EOF
    char_columns
    S:
    _a:      .byte 00,01,02                         ; A
    b:      .byte 03,04,05                         ; B
    c:      .byte 06,07,08                         ; C
    d:      .byte 09,07,10                         ; D
    e:      .byte 03,04,11                         ; E
    f:      .byte 12,01,13                         ; F
    g:      .byte 06,07,14                         ; G
    h:      .byte 15,16,17                         ; H
    i:      .byte 18                               ; I
    j:      .byte 19,20,21                         ; J
    k:      .byte 15,16,22                         ; K
    l:      .byte 23,20,25                         ; L
    m:      .byte 26,62,27,62,28                   ; M
    n:      .byte 26,62,28                         ; N
    o:      .byte 06,07,10                         ; O
    p:      .byte 12,01,29                         ; P
    q:      .byte 06,07,30,25                      ; Q
    r:      .byte 12,01,31                         ; R
    s:      .byte 32,04,33                         ; S
    t:      .byte 34,27,35                         ; T
    u:      .byte 36,20,21                         ; U
    v:      .byte 37,38,39                         ; V
    w:      .byte 36,20,40,20,21                   ; W
    _x:      .byte 41,16,42                         ; X
    _y:      .byte 43,44,45                         ; Y
    z:      .byte 46,04,47                         ; Z
    n0:     .byte 06,07,10                         ; 0
    n1:     .byte 34,28                            ; 1
    n2:     .byte 46,04,48                         ; 2
    n3:     .byte 49,04,05                         ; 3
    n4:     .byte 50,16,17                         ; 4
    n5:     .byte 51,04,33                         ; 5
    n6:     .byte 52,04,33                         ; 6
    n7:     .byte 34,62,28                         ; 7
    n8:     .byte 53,04,05                         ; 8
    n9:     .byte 32,04,54                         ; 9
    cd:     .byte 55                               ; .
    cc:     .byte 56                               ; ,
    cx:     .byte 57                               ; !
    cq:     .byte 58                               ; '
    ck:     .byte 59                               ; :
    ch:     .byte 60,61                            ; -
    spc:    .byte 63				   ; <space>

    char_lens
            .byte 3,3,3,3,3,3,3,3,1,3              ; A-J
	    .byte 3,3,5,3,3,3,4,3,3,3              ; K-T
            .byte 3,3,5,3,3,3                      ; U-Z
            .byte 3,2,3,3,3,3,3,3,3,3              ; 0-9
            .byte 1,1,1,1,1,2,1                    ; punctuation
    char_starts:
            .byte _a-S
            .byte b-S
            .byte c-S
            .byte d-S
            .byte e-S
            .byte f-S
            .byte g-S
            .byte h-S
            .byte i-S
            .byte j-S
            .byte k-S
            .byte l-S
            .byte m-S
            .byte n-S
            .byte o-S
            .byte p-S
            .byte q-S
            .byte r-S
            .byte s-S
            .byte t-S
            .byte u-S
            .byte v-S
            .byte w-S
            .byte _x-S
            .byte _y-S
            .byte z-S
            .byte n0-S
            .byte n1-S
            .byte n2-S
            .byte n3-S
            .byte n4-S
            .byte n5-S
            .byte n6-S
            .byte n7-S
            .byte n8-S
            .byte n9-S
            .byte cd-S
            .byte cc-S
            .byte cx-S
            .byte cq-S
            .byte ck-S
            .byte ch-S
	    .byte spc-S
EOF

