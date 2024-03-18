.PHONY: all clean test

all: build/topple-c build/topple-wasm.py build/stage1 # build/stage2

build/topple-c: src/c/topple.c src/c/topple.h src/c/parse.c \
		src/c/primitives.c src/c/util.c
	@mkdir -p build
	cc -Os -o build/topple-c src/c/topple.c src/c/parse.c src/c/primitives.c \
		src/c/util.c

compiler1 = compiler/misc.tpl compiler/cell.tpl compiler/bytes.tpl \
	compiler/chain.tpl compiler/span.tpl compiler/hashmap.tpl compiler/token.tpl \
	compiler/words.tpl
compiler2 = compiler/args.tpl compiler/parse.tpl compiler/main.tpl

compiler_riscv64 = $(compiler1) compiler/emit-riscv64-linux-elf.tpl $(compiler2)
compiler_wasm    = $(compiler1) compiler/emit-wasm-wasi.tpl $(compiler2)

build/topple-wasm.py: src/simple.py $(compiler_wasm)
	@mkdir -p build
	rm -f build/topple-wasm.py
	cat $(compiler_wasm) \
		| python src/simple.py \
		> build/topple-wasm.py

build/stage1: src/simple.py $(compiler_riscv64)
	@mkdir -p build
	rm -f build/stage1
	cat $(compiler_riscv64) \
		| python src/simple.py \
		| python - -o build/stage1 $(compiler_riscv64)
	chmod +x build/stage1

build/stage2: build/stage1 $(compiler_riscv64)
	@mkdir -p build
	rm -f build/stage2
	qemu-riscv64 ./build/stage1 -o build/stage2 $(compiler_riscv64)
	chmod +x build/stage2

clean:
	rm -rf build

test: build/topple-c build/topple-wasm.py
	python3 test/run.py
