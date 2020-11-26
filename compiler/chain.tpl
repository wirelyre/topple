\ chain.tpl
\
\ A linked list.
\    chain.create ( *chain? ptr count link-size -- )
\    chain.link   ( *chain? ptr -- )
\    chain.unlink ( *chain -- ptr  )
\    chain.count  ( *chain? -- length )
\    chain.empty? ( *chain? -- empty? )
\    chain.move   ( *to? *from -- )
\
\ A chain is a singly-linked list ending in 0.
\ Every link points directly to the next link.
\ Every link contains 'link-size' cells following the 'next' pointer.
\
\ (head)
\   |
\   v     /---link-size---\
\ [next]  [data] ... [data]
\   v
\ [next]  [data] ... [data]
\   v
\ [ 0  ]  [data] ... [data]

type chain



: chain.link over @ over ! >chain swap ! ;
: chain.unlink dup @ <chain tuck @ swap ! ;
: chain.empty? @ null? ;
: chain.move chain.unlink chain.link ;

: chain.create
  1 + -rot 1 -
  begin dup while
    1 - -rot
    3 pick over chain.link
    over +p
    rot
  repeat
  drop tuck
  swap 1 - +p drop   \ ensure length of last link
  chain.link
;

: chain.count
  0 swap @
  begin dup while
    <chain @
    swap 1 + swap
  repeat
  drop
;
