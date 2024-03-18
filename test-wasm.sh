#!/bin/sh

TEMP=`mktemp`
rm "$TEMP"

SOURCES="compiler/misc.tpl compiler/cell.tpl compiler/bytes.tpl \
  compiler/chain.tpl compiler/span.tpl compiler/hashmap.tpl compiler/token.tpl \
  compiler/words.tpl compiler/emit-wasm-wasi.tpl compiler/args.tpl \
  compiler/parse.tpl compiler/main.tpl"

STEP2="compiler/misc.tpl compiler/chain.tpl compiler/span.tpl examples/print-args-span.tpl"
# STEP2="examples/print-args-bytes.tpl"
# STEP2="test-wasm.tpl"

cat $SOURCES | python src/simple.py | python - -o "$TEMP" $STEP2
# python src/python/topple.py $SOURCES -- -o "$TEMP" $STEP2

# wasm2wat "$TEMP"
# xxd "$TEMP"
wasm3 "$TEMP" "test" "with" "arguments"
# wasmer "$TEMP" "test" "with" "arguments"
A=$?

rm "$TEMP"

exit $A
