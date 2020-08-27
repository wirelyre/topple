from pathlib import Path
import sys

from parse import parse
from primitives import primitives
from runtime import ArithPrim, Cell, Get, Primitive, Stack
from util import ParseException, ToppleException


if "--" in sys.argv:
    idx = sys.argv.index("--")
    paths = sys.argv[1:idx]
    args = sys.argv[idx + 1 :]
else:
    paths = sys.argv[1:]
    args = []


argv = bytearray()
for arg in args:
    argv.extend(bytes(arg, "ascii") + b"\0")

defs = {"argv": Get(None, Cell(argv))}


def eprint(s=""):
    print(s, file=sys.stderr)


bold = "\033[1m"
reset = "\033[0m"


try:
    ast = []

    for path in paths:
        source = Path(path).read_text()
        parsed = parse(path, source, primitives, defs)
        ast.extend(parsed)

    stack = Stack()
    for node in ast:
        node.run(stack)

except OSError as e:
    eprint(f"{bold}Error:{reset} could not open '{e.filename}'")

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
