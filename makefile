.PHONY: clean

topple: primitives.c topple.c topple.h util.c
	cc -Os -o topple primitives.c topple.c util.c

clean:
	rm -rf topple
