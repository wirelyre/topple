\ misc.tpl
\
\ Miscellaneous useful words.

: -1 0 1 - ;

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
