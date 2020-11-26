\ span.tpl
\
\ A span of bytes.  Wraps a 'bytes'.
\
\    span.new  ( bytes -- span )
\    span.puts ( span  --      )
\
\    span.peek ( span -- next-byte/EOF )
\    span.bump ( span --               )
\    span.skip ( span --               )
\    span.next ( span -- span          )
\
\    span.=      ( span1 span2 -- equal? )
\    span.empty? ( span        -- empty? )

type span



\ Internals:
\    span: [bytes] [start] [end] [hash]
\
\ A span covers the bytes from 'start' to 'end' in 'bytes'.
\ It also holds the djb2 hash of the bytes it contains.
\ When comparing two spans, this hash (and the length of the spans) are
\   compared first, before comparing each byte.
\
\ If the bytes a span covers are changed, the hash will no longer be correct.
\ If the 'bytes' is cleared, some span operations might cause runtime errors.
\ In all other cases, these words are safe to call.
\ In particular, the 'bytes' may always be appended to.
\
\ There is a chain of free memory to allocate new spans.

: span->bytes      ;
: span->start 1 +p ;
: span->end   2 +p ;
: span->hash  3 +p ;

block.new constant span._heap
0 span._heap !
span._heap span._heap 4 +p 99 3 chain.create

: span._alloc
  span._heap chain.empty? if
    span._heap block.new 100 3 chain.create
  then
  span._heap chain.unlink
;

: span._free
  span._heap swap chain.link
;

: span.new
  span._alloc
       tuck span->bytes !
  0    over span->start !
  0    over span->end   !
  5381 over span->hash  !
  >span
;

: span._EOF?   dup span->end @ swap span->bytes @ bytes.length >= ;
: span._next   dup span->end @ swap span->bytes @ b@ ;
: span._length dup span->end @ swap span->start @ - ;
: span._empty? span._length 0 = ;

: span.empty? <span span._empty? ;

: span.peek
  <span
  dup span._EOF?
    if drop EOF
    else span._next then
;

: span.bump
  <span
  dup span._EOF? if drop exit then
  dup span._next
  over span->hash @
  33 * xor
  over span->hash !
  span->end @1+!
;

: span.skip
  <span
  dup span->end @ over span->start !
  5381            swap span->hash  !
;

: span.next
  <span
  span._alloc
  over span->bytes @ over span->bytes !
  over span->end   @ over span->start !
  over span->end   @ over span->end   !
  5381               over span->hash  !
  >span nip
;

: span._dup
  span._alloc
  over span->bytes @ over span->bytes !
  over span->start @ over span->start !
  over span->end   @ over span->end   !
  over span->hash  @ over span->hash  !
  nip
;

: span._front
  dup span._empty? if EOF exit then
  dup span->start @
  over span->bytes @
  b@
  over span->start @1+!
;

: span.puts
  <span
  span._dup
  begin span._front dup EOF <> while putc repeat
  drop span._free
;

: span.=
  swap <span swap <span
  over span._length over span._length <> if drop drop false exit then
  over span->hash @ over span->hash @ <> if drop drop false exit then

  over span._dup
  over span._dup
  begin span._front dup EOF <> while
    rot span._front rot
    <> if
      span._free span._free drop drop
      false exit
    then
    swap
  repeat
  drop
  span._free span._free drop drop
  true
;
