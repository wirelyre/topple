\ emit-pseudocode.tpl
\
\ Implementation of 'emit' interface that prints simple instructions.
\
\ Like a real emitter, this uses two code sections: one for word definitions,
\ and one for top-level "main" code.  "Main" instructions are indicated by "M"
\ before their instruction number.  Constants and variables are kept in a data
\ section, which the "GET" and "SET" instructions manipulate.
\
\ Only a few primitive words are defined.  They are assigned high instruction
\ numbers.  These are enough to compile 'misc.tpl' as of writing.

variable emit.words-pc
variable emit.main-pc
variable emit.data-counter

0 emit.words-pc!
0 emit.main-pc!
0 emit.data-counter!

: object.init     "initialize object file\n"           ;
: object.finalize "finalize object file\n"   bytes.new ;

: emit._main
  "M" emit.main-pc@ . "  "
  emit.main-pc@ 1 + emit.main-pc!
;

: emit._words
  emit.words-pc@ . "  "
  emit.words-pc@ 1 + emit.words-pc!
;

: emit._data
  emit.data-counter@
  dup 1 + emit.data-counter!
;

: emit.main.word   emit._main "CALL " . "\n" ;
: emit.main.number emit._main "PUSH " . "\n" ;

: emit.type
  "\n"
  emit.words-pc@ swap
  emit._words "OPEN " dup . "\n"
  emit._words "RETURN\n"
  emit.words-pc@ swap
  emit._words "CLOSE " . "\n"
  emit._words "RETURN\n"
  "\n"
;

: emit.constant
  "\n"
  emit.words-pc@
  emit._data
  emit._words "GET " dup . "\n"
  emit._words "RETURN\n"
  "\n"
  emit._main "SET " . "\n"
  "\n"
;

: emit.variable
  "\n"
  emit.words-pc@
  emit._data
  emit._words "GET " dup . "\n"
  emit._words "RETURN\n"
  emit.words-pc@
  emit._words "SET " swap . "\n"
  emit._words "RETURN\n"
  "\n"
;

: emit.word.:
  "\n"
  emit.words-pc@
;
: emit.word.;
  emit._words "RETURN\n"
  "\n"
;

: emit.word.word   emit._words "CALL " . "\n" ;
: emit.word.number emit._words "PUSH " . "\n" ;
: emit.word.string emit._words "PRINT " span.puts "\n" ;

: emit.word.if
  emit.words-pc@
  emit._words "?0BRANCH ___\n"
;
: emit.word.if-else
  emit.words-pc@
  emit._words "JUMP ___\n"
  "( patch " swap . ")\n"
;
: emit.word.if-else-then
  "( patch " . "and " . ")\n"
;
: emit.word.if-then
  "( patch " . ")\n"
;

: emit.word.begin
  emit.words-pc@
;
: emit.word.while
  emit.words-pc@
  emit._words "?0BRANCH ___\n"
;
: emit.word.repeat
  emit._words "JUMP " swap . "\n"
  "( patch " . ")\n"
;

: emit.word.exit
  emit._words "RETURN\n"
;



1001 words.builtin.+ cell.set
1002 words.builtin.- cell.set

1003 words.builtin.and cell.set
1004 words.builtin.or cell.set

1005 words.builtin.= cell.set
1006 words.builtin.<= cell.set

1007 words.builtin.dup cell.set
1008 words.builtin.swap cell.set
1009 words.builtin.tuck cell.set
1010 words.builtin.over cell.set
1011 words.builtin.rot cell.set
1012 words.builtin.-rot cell.set

1013 words.builtin.@ cell.set
1014 words.builtin.! cell.set
