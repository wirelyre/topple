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
