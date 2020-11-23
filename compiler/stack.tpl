\ stack.tpl
\
\ A stack data structure.
\    stack.new   ( -- stack        )
\    stack.peek  ( stack -- cell?  )
\    stack.pop   ( stack --        )
\    stack.push  ( stack -- cell   )
\    stack.count ( stack -- length )

type stack



\ Internals:
\   stack: [items] [free]  [...items...]
\   item:  [next]  [value]
\
\ A stack is two chains: one of items on the stack, and one of memory ready to
\ be used for new pushes.
\
\ A newly-allocated stack lives at the beginning of a block.  The rest of the
\ block is reused for items (initially all on the free chain).  If a push is
\ requested when the free chain is empty, a new block is linked onto the chain.
\
\ Each item 'value' is cast to 'type cell' before returning to the user.

: stack->items      ;
: stack->free  1 +p ;

: stack._top? stack->items @ dup if <chain 1 +p cell.new then ;

: stack.new
  block.new
  0 over stack->items !
  0 over stack->free  !
  dup stack->free over 2 +p
    199 1 chain.create
  >stack
;

: stack.peek <stack stack._top? ;

: stack.pop
  <stack
  dup  stack->free
  swap stack->items
  chain.move
;

: stack._unpop
  dup  stack->items
  swap stack->free
  chain.move
;

: stack.push
  <stack
  dup stack->free chain.empty? if
    dup stack->free block.new 200 1 chain.create
  then
  dup stack._unpop
  stack._top?
;

: stack.count <stack stack->items chain.count ;
