\ parse.tpl
\
\ A parser for Topple programs.  Uses the 'emit' interface.
\
\   parse  ( bytes -- )
\
\ This parser uses the regular stack to keep track of open control structures.
\ 'EOF' marks the top of the parse stack.
\
\ Some structures need to keep track of addresses while open; these are stored
\ underneath the tokens.  For example:
\   EOF   (addr) if   (addr) (addr) while
\
\ The 'if' address marks the open 'if'.  The 'while' addresses mark both
\ 'begin' and 'while' in the open loop.
\
\ The current token span is stored in a variable so that line-column error
\ reporting will be possible in the future.



: parse._mismatched "mismatched control word\n" 1 fail ;
: parse._not-in-def "control words only allowed in definitions\n" 1 fail ;
: parse._not-in-main "defining words only allowed at top level\n" 1 fail ;

variable parse._tok
variable parse._type-number
0 parse._type-number!

: parse._next-name
  parse._tok@ token.next
  token.word <> if "expected name\n" 1 fail then
;



: parse
  span.new parse._tok!

  EOF

  begin
    parse._tok@ span.next parse._tok!
    parse._tok@ token.next
    dup EOF <>
  while



    dup token.number = if drop nip
      over EOF = if
        emit.main.number
      else
        emit.word.number
      then

    else dup token.word = if drop
      words hashmap.find

      dup null? if "undefined word\n" 1 fail then
      cell.get

      over EOF = if
        emit.main.word
      else
        emit.word.word
      then

    else dup token.string = if drop
      over EOF = if parse._not-in-def then
      emit.word.string



    else dup token.: = if drop drop
      dup EOF <> if parse._not-in-main then
      parse._next-name
      words.user
      emit.word.:
      swap cell.set
      token.:

    else dup token.; = if drop drop
      dup token.: <> if parse._mismatched then
      emit.word.;
      drop

    else dup token.constant = if drop drop
      dup EOF <> if parse._not-in-main then
      parse._next-name
      words.user
      emit.constant
      swap cell.set

    else dup token.variable = if drop drop
      dup EOF <> if parse._not-in-main then
      parse._next-name
      emit.variable
      2 pick words.user.setter cell.set
      swap   words.user.getter cell.set

    else dup token.type = if drop drop
      dup EOF <> if parse._not-in-main then
      parse._next-name
      parse._type-number@
      dup 1 + parse._type-number!
      emit.type
      2 pick words.user.closer cell.set
      swap   words.user.opener cell.set



    else dup token.if = if drop drop
      dup EOF = if parse._not-in-def then
      emit.word.if
      token.if

    else dup token.else = if drop drop
      dup EOF = if parse._not-in-def then
      dup token.if <> if parse._mismatched then
      drop
      dup emit.word.if-else
      token.else

    else dup token.then = if drop drop
      dup EOF = if parse._not-in-def then
      dup token.if = if
        drop
        emit.word.if-then
      else dup token.else = if
        drop
        emit.word.if-else-then
      then then

    else dup token.begin = if drop drop
      dup EOF = if parse._not-in-def then
      emit.word.begin
      token.begin

    else dup token.while = if drop drop
      dup EOF = if parse._not-in-def then
      dup token.begin <> if parse._mismatched then
      drop
      emit.word.while
      token.while

    else dup token.repeat = if drop drop
      dup EOF = if parse._not-in-def then
      dup token.while <> if parse._mismatched then
      drop
      emit.word.repeat

    else dup token.exit = if drop drop
      emit.word.exit

    then then then then then then then then then then then then then then then



  repeat drop drop

  EOF <> if "unclosed control structure\n" 1 fail then
;
