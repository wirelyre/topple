: nl "\n" ;

bytes.new constant b

b bytes.length .   \ 0
1 b b%
b bytes.length .   \ 1
b bytes.clear
b bytes.length .   \ 0

: fill
  0 begin dup 65536 < while
    dup b b%
  1 + repeat drop
;
fill

b bytes.length .   \ 65536

nl
