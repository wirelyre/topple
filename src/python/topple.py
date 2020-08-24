import sys

from parse import parse
from primitives import primitives
from runtime import ArithPrim, Cell, Get, Primitive, Stack
from util import ParseException, ToppleException


argv = bytearray()
for arg in sys.argv[1:]:
    argv.extend(bytes(arg, "ascii") + b"\0")


source = sys.stdin.read()
defs = {"argv": Get(None, Cell(argv))}


bold = "\033[1m"
reset = "\033[0m"


try:
    ast = parse("(stdin)", source, primitives, defs)

    stack = Stack()
    for node in ast:
        node.run(stack)

except ParseException as e:
    print(f"{bold}Parse error:{reset} {e.args[0]}")
    print(f"at {e.args[1]}")
    if len(e.args) > 2:
        print(f"see {e.args[2]}")

except ToppleException as e:

    print(f"{bold}Error:{reset} {e.args[0]}")
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
