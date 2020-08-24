.PHONY: clean

build/topple-c: src/c/topple.c src/c/topple.h src/c/parse.c \
		src/c/primitives.c src/c/util.c
	@mkdir -p build
	cc -Os -o build/topple-c src/c/topple.c src/c/parse.c src/c/primitives.c \
		src/c/util.c

clean:
	rm -rf build
