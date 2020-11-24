: print-arg \ i -- i+something
    begin
      dup argv b@
      dup 0 <>
    while
      putc
      1 +
    repeat
    drop 1 +
;

: print-args \ --
    0
    begin
      dup argv bytes.length <
    while
      print-arg "\n"
    repeat
    drop
;

print-args
