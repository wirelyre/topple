\ OK -- 0 1 0 4096 0 0 1 2 3 0 1 1 4097 0 1 2 

bytes.new constant b
bytes.new constant b'

b bytes.length .   \ 0
1 b b%
b bytes.length .   \ 1
b bytes.clear
b bytes.length .   \ 0

: fill
  0 begin dup 4096 < while
    dup b b%
  1 + repeat drop
;
fill

b bytes.length .   \ 4096
b' bytes.length .  \ 0

0 b b@ .           \ 0
1 b b@ .           \ 1
2 b b@ .           \ 2
3 b b@ .           \ 3
256 b b@ .         \ 0
257 b b@ .         \ 1

1 b' b%
2 0 b' b!
b' bytes.length .  \ 1
0 b b%
b bytes.length .   \ 4097

b bytes.clear
b bytes.length .   \ 0

b' bytes.length .  \ 1
0 b' b@ .          \ 2
