\ args.tpl
\
\ Command-line argument parser.  Interprets command lines of this form:
\    ./compiler -o [output-file] [input-files ...]
\
\    args.output-file     ( -- span  )
\    args.next-input-file ( -- span? )

argv span.new constant args.output-file

: args._usage
  "Usage: ./compiler -o [output-file] [input-files ...]\n"
  1 fail
;

: args._next-arg
  dup span.skip
  begin
    dup span.peek
    dup  0 <>
    swap EOF <> and
  while dup span.bump
  repeat
;

: args._init-parser
  args.output-file
  dup span.peek 45  <> if args._usage then dup span.bump
  dup span.peek 111 <> if args._usage then dup span.bump
  dup span.peek 0   <> if args._usage then dup span.bump

  args._next-arg
  dup span.empty? if args._usage then
  span.next
;

args._init-parser
constant args._current

: args.next-input-file
  args._current
  dup span.bump
  dup span.peek EOF = if drop 0 exit then
  args._next-arg
;
