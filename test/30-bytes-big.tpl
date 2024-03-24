\ OK -- 0 3 0 0 1 

bytes.new constant b1

b1 bytes.length . \ 0

10 b1 b%
11 b1 b%
12 b1 b%

b1 bytes.length . \ 3

: realloc
  0 begin dup 65536 < while
    dup b1 b%
  1 + repeat drop
;
realloc

bytes.new constant b2

b2 bytes.length . \ 0
20 b1 b%
b2 bytes.length . \ 0
21 b2 b%
b2 bytes.length . \ 1
