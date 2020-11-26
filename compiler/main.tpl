\ main.tpl
\
\ Drives the compiler.

: main
  "Output file: " args.output-file span.puts "\n\n"

  "Input files:\n"

  begin
    args.next-input-file
  dup while
    span.puts "\n"
  repeat drop
;

main
