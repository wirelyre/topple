import sys

from parse import parse
from primitives import primitives
from runtime import ArithPrim, Primitive, Stack


source = sys.stdin.read()
defs = {}

ast = parse("(stdin)", source, primitives, defs)

stack = Stack()
for node in ast:
    node.run(stack)
