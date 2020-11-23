\ cell.tpl
\
\ A cell data structure.  Like a block, except it only holds one thing.
\
\   cell.new  ( ptr  -- cell  )
\   cell.new? ( ptr? -- cell? )
\   cell.get  ( cell -- value )
\   cell.set  ( value cell -- )
\
\ A cell returned from a word means that only the memory location at that cell
\ should be considered user-writable.  Maybe the surrounding memory is part of
\ a data structure.  In any case, no pointer arithmetic should be performed on
\ a cell.
\
\ The words '>cell' and '<cell' should never occur outside of this module.

type cell

: cell.new >cell   ;
: cell.get <cell @ ;
: cell.set <cell ! ;
: cell.new? dup if >cell then ;
