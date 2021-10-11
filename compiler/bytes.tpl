\ bytes.tpl
\
\ Words for manipulating byte arrays.
\
\   bytes.dump   ( bytes -- )
\   bytes.append ( into from -- into )
\
\   b%1 ( bytes n -- bytes )
\   b%2 ( bytes n -- bytes )
\   b%4 ( bytes n -- bytes )
\   b%8 ( bytes n -- bytes )
\
\   b!2 ( n idx bytes -- )
\   b!4 ( n idx bytes -- )

: bytes.dump
  0
  begin
    over bytes.length
    over >
  while
    2dup swap b@ .x " "
    1 +
    dup 15 and 0 = if "\n" then
  repeat
  drop drop
  "\n"
;

: bytes.append
  0
  begin
    over bytes.length
    over >
  while
    2dup swap b@
    3 pick b%
    1 +
  repeat
  drop drop
;

: b%1
  2dup swap b% drop
;

: b%2
  2dup swap b% 8 >>
  2dup swap b% drop
;

: b%4
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% drop
;

: b%8
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% 8 >>
  2dup swap b% drop
;

: b!2
  2 pick  8 >> 255 and   2 pick 1 +   2 pick b!
  rot 255 and -rot   b!
;

: b!4
  2 pick 24 >> 255 and   2 pick 3 +   2 pick b!
  2 pick 16 >> 255 and   2 pick 2 +   2 pick b!
  2 pick  8 >> 255 and   2 pick 1 +   2 pick b!
  rot 255 and -rot   b!
;
