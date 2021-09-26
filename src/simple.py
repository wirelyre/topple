import re, sys


source = sys.stdin.read()


WHITESPACE = re.compile(
    r""" ^(
        [ \n] |     # whitespace or
        \\ [^\n]*   # a comment
    )* """,
    re.X,
)
NUMBER = re.compile("^[0-9]+$")
STRING = re.compile(r'^"([^\\]|\\.)*?"')
WORD = re.compile("^[!#-\[\]-~]+")


def skip_ws():
    global source

    ws = WHITESPACE.match(source)
    if ws is not None:
        source = source[ws.end() :]


def next_token():
    global source

    s = STRING.match(source)
    w = WORD.match(source)

    if s is not None:
        source = source[s.end() :]
        return s.group(0)

    elif w is not None:
        source = source[w.end() :]
        return w.group(0)

    else:
        raise Exception("bad input")


print(
    """
import sys


S = []


def num(i):
    return i & 0xFFFFFFFFFFFFFFFF

def arith(f):
    return lambda: S.append(num(f(S.pop(), S.pop())))
def comp(f):
    return lambda: S.append(num(-f(S.pop(), S.pop())))

add = arith(lambda r, l: l + r)
sub = arith(lambda r, l: l - r)
mul = arith(lambda r, l: l * r)
div = arith(lambda r, l: l // r)
shl = arith(lambda r, l: l << (r % 64))
shr = arith(lambda r, l: l >> (r % 64))

not_ = lambda: S.append(num(~S.pop()))
and_ = arith(lambda r, l: l & r)
or_ = arith(lambda r, l: l | r)
xor = arith(lambda r, l: l ^ r)

eq = comp(lambda r, l: l == r)
ne = comp(lambda r, l: l != r)
lt = comp(lambda r, l: l < r)
gt = comp(lambda r, l: l > r)
le = comp(lambda r, l: l <= r)
ge = comp(lambda r, l: l >= r)

dup = lambda: S.append(S[-1])
drop = lambda: S.pop()
swap = lambda: S.append(S.pop(-2))
nip = lambda: S.pop(-2)
tuck = lambda: S.insert(-2, S[-1])
over = lambda: S.append(S[-2])

def rot():
    v2, v1, v0 = S.pop(), S.pop(), S.pop()
    S.extend([v1, v2, v0])
def unrot():
    v2, v1, v0 = S.pop(), S.pop(), S.pop()
    S.extend([v2, v0, v1])
def pick():
    i = S.pop()
    S.append(S[-i - 1])

dot = lambda: sys.stderr.write(str(S.pop()) + " ")
putc = lambda: sys.stderr.write(chr(S.pop()))
fail = lambda: sys.exit(S.pop())

bytes_new = lambda: S.append(bytearray())
bytes_length = lambda: S.append(num(len(S.pop())))

def bytes_clear():
    b = S.pop()
    del b[:]

def bytes_push():
    b, c = S.pop(), S.pop()
    b.append(c & 0xFF)

def bytes_get():
    b, idx = S.pop(), S.pop()
    S.append(b[idx])

def bytes_set():
    b, idx, c = S.pop(), S.pop(), S.pop()
    b[idx] = c


def file_read():
    filename = S.pop()
    try:
        with open(bytes(filename), "rb") as file:
            contents = file.read()
            S.append(bytearray(contents))
    except IOError:
        S.append(0)


def block_new():
    S.append({"block": [None] * 400, "index": 0})

def pointer_get():
    ptr = S.pop()
    S.append(ptr["block"][ptr["index"]])

def pointer_set():
    ptr, val = S.pop(), S.pop()
    ptr["block"][ptr["index"]] = val

def pointer_offset():
    off, ptr = S.pop(), S.pop()
    idx = num(ptr["index"] + off)
    assert 0 <= idx < 400
    S.append({"block": ptr["block"], "index": idx})


argv = bytearray()
for arg in sys.argv:
    argv.extend(arg.encode("ascii") + b"\\0")
push_argv = lambda: S.append(argv)


"""
)


indent = 0
words = {
    "+": "add",
    "-": "sub",
    "*": "mul",
    "/": "div",
    "<<": "shl",
    ">>": "shr",
    "not": "not_",
    "and": "and_",
    "or": "or_",
    "xor": "xor",
    "=": "eq",
    "<>": "ne",
    "<": "lt",
    ">": "gt",
    "<=": "le",
    ">=": "ge",
    "dup": "dup",
    "drop": "drop",
    "swap": "swap",
    "nip": "nip",
    "tuck": "tuck",
    "over": "over",
    "rot": "rot",
    "-rot": "unrot",
    "pick": "pick",
    ".": "dot",
    "putc": "putc",
    "fail": "fail",
    "bytes.new": "bytes_new",
    "bytes.clear": "bytes_clear",
    "bytes.length": "bytes_length",
    "b%": "bytes_push",
    "b@": "bytes_get",
    "b!": "bytes_set",
    "file.read": "file_read",
    "block.new": "block_new",
    "@": "pointer_get",
    "!": "pointer_set",
    "+p": "pointer_offset",
    "argv": "push_argv",
}
word_idx = 0


def print_indented(s):
    for _ in range(indent):
        sys.stdout.write("    ")
    sys.stdout.write(s + "\n")


while True:
    skip_ws()

    if source == "":
        break

    tok = next_token()

    if tok == ":":
        skip_ws()
        word = next_token()
        py_name = "word_" + str(word_idx)
        words[word] = py_name

        print_indented("def " + py_name + "():  # " + word)
        indent += 1
        print_indented("pass")

        word_idx += 1

    elif tok == ";":
        indent -= 1

    elif tok == "constant":
        skip_ws()
        word = next_token()

        const_name = "const_" + str(word_idx)
        word_name = "word_" + str(word_idx)
        words[word] = word_name

        print_indented(const_name + " = S.pop()  # constant " + word)
        print_indented(word_name + " = lambda: S.append(" + const_name + ")")

        word_idx += 1

    elif tok == "variable":
        skip_ws()
        word = next_token()

        var_name = "var_" + str(word_idx)
        getter = "get_" + str(word_idx)
        setter = "set_" + str(word_idx)
        words[word + "@"] = getter
        words[word + "!"] = setter

        print_indented(getter + " = lambda: S.append(" + var_name + ")")
        print_indented("def " + setter + "():  # variable " + word)
        indent += 1
        print_indented("global " + var_name)
        print_indented(var_name + " = S.pop()")
        indent -= 1

        word_idx += 1

    elif tok == "if":
        print_indented("if S.pop() != 0:")
        indent += 1
        print_indented("pass")
    elif tok == "else":
        indent -= 1
        print_indented("else:")
        indent += 1
        print_indented("pass")
    elif tok == "then":
        indent -= 1

    elif tok == "begin":
        print_indented("while True:")
        indent += 1
        print_indented("pass")
    elif tok == "while":
        print_indented("if S.pop() == 0: break")
    elif tok == "repeat":
        indent -= 1

    elif tok[0] == '"':
        print_indented("sys.stderr.write(" + tok + ")")

    elif NUMBER.match(tok):
        print_indented("S.append(num(" + tok + "))")

    elif tok in words:
        print_indented(words[tok] + "()  # " + tok)

    else:
        raise Exception("undefined word")
