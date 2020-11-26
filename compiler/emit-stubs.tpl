\ emit-stubs.tpl
\
\ Stubs for emitting object files and object code.
\ The address and generated code are kept as global state.
\ This interface is intended to be shared by each backend.
\
\ Some words save state which is provided to later words.
\
\ For example, 'emit.word.if' can save an address which 'emit.word.if-then'
\ can use later.  And 'emit.variable' can save addresses of the newly defined
\ getter and setter.
\
\ These will be documented later.

: object.init     "initialize object file\n"           ;
: object.finalize "finalize object file\n"   bytes.new ;

: emit.main.word   "word in main: " . "\n"   ;
: emit.main.number "number in main: " . "\n" ;

: emit.type     "type: " . "\n" 0 0 ;
: emit.constant "constant\n"    0   ;
: emit.variable "variable\n"    0 0 ;

: emit.word.:            "start of word\n"                 0 ;
: emit.word.;            "end of word\n"                     ;
: emit.word.word         "    word in word: " . "\n"         ;
: emit.word.number       "    number in word: " . "\n"       ;
: emit.word.if           "    if\n"                        0 ;
: emit.word.if-else      "    if-else: " . "\n"            0 ;
: emit.word.if-else-then "    if-else-then: " . " " . "\n"   ;
: emit.word.if-then      "    if-then: " . "\n"              ;
: emit.word.begin        "    begin\n"                     0 ;
: emit.word.while        "    while\n"                     0 ;
: emit.word.repeat       "    repeat: " . " " . "\n"         ;
