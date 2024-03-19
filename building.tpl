block.new constant mem

type a
type b

mem >a   \ stack: a
<a       \ stack: ptr
drop

mem >b   \ stack: b
<b       \ stack: ptr
drop

mem >a <b   \ illegal
