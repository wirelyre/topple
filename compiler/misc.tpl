\ misc.tpl
\
\ Miscellaneous useful words.

: -1 0 1 - ;
: neg  0 swap - ;

: true  -1 ;
: false  0 ;
: EOF   -1 ;

: null? if false else true then ;

: @1+! dup @ 1 + swap ! ;
: 2dup over over ;

: =or     rot tuck = -rot = or ;          \ ( a b c -- a=b||a=c )
: between -rot over <= -rot swap <= and ; \ ( b a c -- a<=b<=c  )

: .h   dup 9 > 7 and 48 + + putc ;
: .x   dup 4 >> .h   15 and .h ;
: .s   dup 63 >> if "-" neg . else "+" . then ;

: sext   2dup 1 - >> neg swap << or ;   \ (n bitwidth -- n)
: >>s    over 63 >> 0 <> over 64 swap - << -rot >> or ;   \ (n amt -- n>>amt)

type todo
: TODO <todo ;
