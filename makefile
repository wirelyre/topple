.PHONY: all clean test

all: build/topple-c build/stage1 build/stage2

build/topple-c: src/c/topple.c src/c/topple.h src/c/parse.c \
		src/c/primitives.c src/c/util.c
	@mkdir -p build
	cc -Os -o build/topple-c src/c/topple.c src/c/parse.c src/c/primitives.c \
		src/c/util.c

compiler_sources = compiler/misc.tpl compiler/cell.tpl compiler/bytes.tpl \
	compiler/chain.tpl compiler/span.tpl compiler/hashmap.tpl \
	compiler/token.tpl compiler/words.tpl compiler/emit-riscv64-linux-elf.tpl \
	compiler/args.tpl compiler/parse.tpl compiler/main.tpl

build/stage1: src/simple.py $(compiler_sources)
	@mkdir -p build
	rm -f build/stage1
	cat $(compiler_sources) \
		| python src/simple.py \
		| python - -o build/stage1 $(compiler_sources)
	chmod +x build/stage1

build/stage2: build/stage1 $(compiler_sources)
	@mkdir -p build
	rm -f build/stage2
	qemu-riscv64 ./build/stage1 -o build/stage2 $(compiler_sources)
	chmod +x build/stage2

clean:
	rm -rf build

test: build/topple-c
	python3 test/run.py
