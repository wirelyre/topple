\ token.tpl
\
\ A tokenizer for Topple programs.  Also identifies control words.
\
\   token.next  ( span -- span (n)? kind/EOF )
\
\ 'token.next' advances the given span to cover the next token, if any.
\ The possible token kinds are listed below.
\
\ If 'kind' is 'token.number', then 'n' is the token's numeric value.
\ Otherwise 'n' is not provided, and the word returns only two values.

 0 constant token.number
 1 constant token.word
 2 constant token.string

 3 constant token.:
 4 constant token.;
 5 constant token.constant
 6 constant token.variable
 7 constant token.type

 8 constant token.if
 9 constant token.else
10 constant token.then
11 constant token.begin
12 constant token.while
13 constant token.repeat
14 constant token.exit



hashmap.new   constant token._map
bytes.new dup constant token._bytes
              variable token._span

span.new token._span!

: token._add
  begin dup while
    token._bytes b%
    token._span@ span.bump
  repeat
  drop

  token._span@
  dup span.next token._span!

  token._map hashmap.insert
  cell.set
;

token.:          0 58                            token._add
token.;          0 59                            token._add
token.constant   0 116 110 97 116 115 110 111 99 token._add
token.variable   0 101 108 98 97 105 114 97 118  token._add
token.type       0 101 112 121 116               token._add

token.if         0 102 105                       token._add
token.else       0 101 115 108 101               token._add
token.then       0 110 101 104 116               token._add
token.begin      0 110 105 103 101 98            token._add
token.while      0 101 108 105 104 119           token._add
token.repeat     0 116 97 101 112 101 114        token._add
token.exit       0 116 105 120 101               token._add



: token._skip-ws
  begin 1 while
    dup span.peek

    dup 10 32 =or if drop dup span.bump

    else 92 = if
      dup span.bump
      begin
        dup span.peek
        dup 10  <> swap
            EOF <> and
      while
        dup span.bump
      repeat

    else
      span.skip
      exit
    then then
  repeat
;

: token._is-ws-or-EOF
  dup 10 = swap
  dup 32 = swap
  dup 92 = swap
  EOF = or or or
;

: token._bump-string
  dup span.bump
  begin 1 while
    dup span.peek

    dup 34 = if drop
      dup span.bump
      token.string exit

    else dup 92 = if drop
      dup span.bump
      dup span.bump

    else dup EOF = if 1 fail

    else drop
      dup span.bump
    then then then
  repeat
;

: token.next
  dup token._skip-ws

  dup span.peek
  dup EOF = if exit then
  dup 34 = if drop token._bump-string exit then

  0
  begin
    over 48 57 between
  while
    10 * + 48 -
    over span.bump
    over span.peek
    dup token._is-ws-or-EOF if
      drop token.number exit
    then
    swap
  repeat

  drop drop
  begin
    dup span.peek token._is-ws-or-EOF not
  while
    dup span.bump
  repeat

  dup token._map hashmap.find dup
  if cell.get
  else drop token.word
  then
;
