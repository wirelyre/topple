.PHONY: all clean

all: build/topple-asm build/topple-c

build/topple-asm: asm/topple.s
	@mkdir -p build
	cc -g -m64 -nostartfiles -nostdlib -o build/topple-asm asm/topple.s

build/topple-c: c/topple.c c/topple.h c/parse.c c/primitives.c c/util.c
	@mkdir -p build
	cc -Os -o build/topple-c c/topple.c c/parse.c c/primitives.c c/util.c

clean:
	rm -rf build
