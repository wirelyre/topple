argv span.new constant arg

: next-arg \ --
    arg <span span->end @
      0 <> if arg span.bump then
    arg span.skip
    begin
      arg span.peek
      dup  0 <>
      swap EOF <> and
    while
      arg span.bump
    repeat
;

: more-args? arg span.peek EOF <> ; \ -- more?

: print-args \ --
    begin
      next-arg
      more-args?
    while
      arg span.puts
      "\n"
    repeat
;

print-args
