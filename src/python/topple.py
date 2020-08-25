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


def eprint(s=""):
    print(s, file=sys.stderr)


bold = "\033[1m"
reset = "\033[0m"


try:
    ast = parse("(stdin)", source, primitives, defs)

    stack = Stack()
    for node in ast:
        node.run(stack)

except ParseException as e:
    eprint(f"{bold}Parse error:{reset} {e.args[0]}")
    eprint(f"at {e.args[1]}")
    if len(e.args) > 2:
        eprint(f"see {e.args[2]}")

except ToppleException as e:

    eprint()

    eprint(f"{bold}Error:{reset} {e.args[0]}")
    if e.hint:
        eprint(e.hint)
    eprint()

    eprint(f"{bold}Backtrace:{reset}")
    for name in e.backtrace:
        eprint(name)
    eprint()

    eprint(f"{bold}Stack:{reset}")
    for v in reversed(e.captured_stack):
        eprint(v)

    eprint(f"{bold}------{reset}")
    for v in reversed(stack[-10:]):
        eprint(v)
    if len(stack) > 10:
        eprint("...")

    sys.exit(127)
