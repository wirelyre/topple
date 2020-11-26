\ hashmap.tpl
\
\ A hash map with spans for keys.
\    hashmap.new    (             -- hashmap     )
\    hashmap.find   ( key hashmap -- entry-cell? )
\    hashmap.insert ( key hashmap -- entry-cell  )

type hashmap



\ Internals:
\    hashmap: [entries] [free]
\    entry:   [next] [key] [value]
\
\ A 'hashmap' is a simple chain of key-value pairs.
\ New entries are linked onto the front.
\ Each map has a chain of free memory for allocating new entries.

: hashmap->entries          ;
: hashmap->free        1 +p ;
: hashmap.entry->next       ;
: hashmap.entry->key   1 +p ;
: hashmap.entry->value 2 +p ;

: hashmap.new
  block.new
  0 over hashmap->entries !
  0 over hashmap->free    !
  dup hashmap->free over 2 +p 132 2 chain.create
  >hashmap
;

: hashmap.find
  <hashmap
  swap <span >span swap
  hashmap->entries @
  begin dup while
    <chain
    2dup hashmap.entry->key @
    span.= if
      hashmap.entry->value cell.new
      nip
      exit
    then
    @
  repeat
  nip
;

: hashmap.insert
  <hashmap
  swap <span >span swap
  dup hashmap->free chain.empty? if
    dup hashmap->free
    block.new 133 2 chain.create
  then
  dup hashmap->free chain.unlink
  swap hashmap->entries over chain.link
  tuck hashmap.entry->key !
  hashmap.entry->value cell.new
;
