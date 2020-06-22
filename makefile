.PHONY: clean

build/topple-c: c/topple.c c/topple.h c/parse.c c/primitives.c c/util.c
	@mkdir -p build
	cc -Os -o build/topple-c c/topple.c c/parse.c c/primitives.c c/util.c

clean:
	rm -rf build
