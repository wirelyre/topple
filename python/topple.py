import sys

from parse import parse
from primitives import primitives
from runtime import ArithPrim, Cell, Get, Primitive, Stack


argv = bytearray()
for arg in sys.argv[1:]:
    argv.extend(bytes(arg, "ascii") + b"\0")


source = sys.stdin.read()
defs = {"argv": Get(None, Cell(argv))}

ast = parse("(stdin)", source, primitives, defs)

stack = Stack()
for node in ast:
    node.run(stack)
