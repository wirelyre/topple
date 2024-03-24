.PHONY: all clean test

all: build/c/topple build/riscv64/topple build/wasm/topple



COMPILER_LIB = compiler/misc.tpl compiler/cell.tpl compiler/bytes.tpl \
	compiler/chain.tpl compiler/span.tpl compiler/hashmap.tpl compiler/token.tpl \
	compiler/words.tpl
COMPILER_DRIVER = compiler/args.tpl compiler/parse.tpl compiler/main.tpl

COMPILER_RISCV64 = $(COMPILER_LIB) compiler/emit-riscv64-linux-elf.tpl $(COMPILER_DRIVER)
COMPILER_WASM = $(COMPILER_LIB) compiler/emit-wasm-wasi.tpl $(COMPILER_DRIVER)



build/c/topple: src/c/topple.c src/c/topple.h src/c/parse.c \
		src/c/primitives.c src/c/util.c
	@mkdir -p build/c
	cc -Os -o build/c/topple src/c/topple.c src/c/parse.c src/c/primitives.c \
		src/c/util.c



build/riscv64/topple: src/simple.py $(COMPILER_RISCV64)
	@mkdir -p build/riscv64
	rm -f build/riscv64/topple
	cat $(COMPILER_RISCV64) \
		| python src/simple.py \
		| python - -o build/riscv64/topple $(COMPILER_RISCV64)
	chmod +x build/riscv64/topple

build/riscv64/verify: build/riscv64/topple $(COMPILER_RISCV64)
	rm -f build/riscv64/verify
	qemu-riscv64 ./build/riscv64/topple -o build/riscv64/verify $(COMPILER_RISCV64)
	chmod +x build/riscv64/verify



build/wasm/topple: src/simple.py $(COMPILER_WASM)
	@mkdir -p build/wasm
	rm -f build/wasm/topple
	cat $(COMPILER_WASM) \
		| python src/simple.py \
		| python - -o build/wasm/topple $(COMPILER_WASM)

build/wasm/verify: build/wasm/topple $(COMPILER_WASM)
	rm -f build/wasm/verify
	wasm3 build/wasm/topple -o build/wasm/verify $(COMPILER_WASM)



clean:
	rm -rf build

test: build/c/topple build/wasm/topple
	python3 test/run.py
