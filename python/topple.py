import sys

from parse import parse
from primitives import primitives
from runtime import ArithPrim, Cell, Get, Primitive, Stack
from util import ToppleException


argv = bytearray()
for arg in sys.argv[1:]:
    argv.extend(bytes(arg, "ascii") + b"\0")


source = sys.stdin.read()
defs = {"argv": Get(None, Cell(argv))}

ast = parse("(stdin)", source, primitives, defs)

try:
    stack = Stack()
    for node in ast:
        node.run(stack)

except ToppleException as e:
    bold = "\033[1m"
    reset = "\033[0m"

    print(f"{bold}Error:{reset} " + e.args[0])
    if e.hint:
        print(e.hint)
    print()

    print(f"{bold}Backtrace:{reset}")
    for name in e.backtrace:
        print(name)
    print()

    print(f"{bold}Stack:{reset}")
    for v in reversed(e.captured_stack):
        print(v)

    print(f"{bold}------{reset}")
    for v in reversed(stack[-10:]):
        print(v)
    if len(stack) > 10:
        print("...")

    sys.exit(127)
