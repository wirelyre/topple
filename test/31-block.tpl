\ OK -- 0 1 2 3 7 

block.new constant a
block.new constant b

0 a !
1 b !

a @ . \ 0
b @ . \ 1

2 a 4 +p !
3 a 5 +p !

a 4 +p @ . \ 2
a 5 +p @ . \ 3

6 b 4 +p !
7 b 4 +p !

b 4 +p @ . \ 7
