#!/bin/sh

TEMP=`mktemp`
rm "$TEMP"

python src/python/topple.py \
  compiler/misc.tpl compiler/cell.tpl compiler/bytes.tpl compiler/chain.tpl \
  compiler/span.tpl compiler/hashmap.tpl compiler/token.tpl compiler/words.tpl \
  compiler/emit-wasm-wasi.tpl compiler/args.tpl compiler/parse.tpl \
  compiler/main.tpl \
  -- -o "$TEMP" building.tpl # compiler/misc.tpl

wasm3 "$TEMP"
A=$?

rm "$TEMP"

exit $A
