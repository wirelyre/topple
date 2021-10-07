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
