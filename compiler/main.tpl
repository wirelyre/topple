\ main.tpl
\
\ Drives the compiler.

: main
  "Output file: " args.output-file span.puts "\n\n"

  bytes.new

  begin
    args.next-input-file
  dup while

    over dup bytes.clear
    swap span.b%
    file.read
    dup if else "cannot open file\n" 1 fail then

    parse

  repeat drop

  drop
;

main
