from sys import stderr
from typing import Any

from runtime import ArithPrim, Pointer, Primitive


add = lambda l, r: l + r
sub = lambda l, r: l - r
mul = lambda l, r: l * r
div = lambda l, r: l // r
shl = lambda l, r: l << (r % 64)
shr = lambda l, r: l >> (r % 64)

eq = lambda l, r: l == r
ne = lambda l, r: l != r
lt = lambda l, r: l < r
gt = lambda l, r: l > r
le = lambda l, r: l <= r
ge = lambda l, r: l >= r


def dup(s):
    [v] = s.pop([Any])
    s.append([v, v])


def drop(s):
    s.pop([Any])


def swap(s):
    [v0, v1] = s.pop([Any, Any])
    s.append([v1, v0])


def nip(s):
    [_, v] = s.pop([Any, Any])
    s.append([v])


def tuck(s):
    [v0, v1] = s.pop([Any, Any])
    s.append([v1, v0, v1])


def over(s):
    [v0, v1] = s.pop([Any, Any])
    s.append([v0, v1, v0])


def rot(s):
    [v0, v1, v2] = s.pop([Any, Any, Any])
    s.append([v1, v2, v0])


def unrot(s):
    [v0, v1, v2] = s.pop([Any, Any, Any])
    s.append([v2, v0, v1])


def pick(s):
    [n] = s.pop([int])
    v = s.pick(n)
    s.append([v])


def dot(s):
    [n] = s.pop([int])
    print(n, end=" ", file=stderr)


def putc(s):
    [n] = s.pop([int])
    c = chr(n)
    if (c.isascii() and c.isprintable()) or c == " " or c == "\n":
        print(c, end="", file=stderr)
    else:
        raise Exception("TODO")


def bytes_new(s):
    s.append([bytearray()])


def bytes_clear(s):
    [b] = s.pop([bytearray])
    b.clear()


def bytes_length(s):
    [b] = s.pop([bytearray])
    l = len(b) & 0xFFFF_FFFF_FFFF_FFFF
    s.append([l])


def bytes_push(s):
    [c, b] = s.pop([int, bytearray])
    b.append(c & 0xFF)


def bytes_get(s):
    [idx, b] = s.pop([int, bytearray])
    c = b[idx]
    s.append([c])


def bytes_set(s):
    [c, idx, b] = s.pop([int, int, bytearray])
    b[idx] = c


def file_read(s):
    [filename] = s.pop([bytearray])
    try:
        with open(bytes(filename), "rb") as file:
            contents = file.read()
            s.append([bytearray(contents)])
    except IOError:
        s.append([0])


def block_new(s):
    s.append([Pointer()])


def pointer_get(s):
    [p] = s.pop([Pointer])
    s.append([p.get()])


def pointer_set(s):
    [v, p] = s.pop([Any, Pointer])
    p.set(v)


def pointer_offset(s):
    [p, offset] = s.pop([Pointer, int])
    s.append([p.with_offset(offset)])


primitives = {
    "+": ArithPrim(None, add),
    "-": ArithPrim(None, sub),
    "*": ArithPrim(None, mul),
    "/": ArithPrim(None, div),
    "<<": ArithPrim(None, shl),
    ">>": ArithPrim(None, shr),
    "=": ArithPrim(None, eq),
    "<>": ArithPrim(None, ne),
    "<": ArithPrim(None, lt),
    ">": ArithPrim(None, gt),
    "<=": ArithPrim(None, le),
    ">=": ArithPrim(None, ge),
    "dup": Primitive(None, dup),
    "drop": Primitive(None, drop),
    "swap": Primitive(None, swap),
    "nip": Primitive(None, nip),
    "tuck": Primitive(None, tuck),
    "over": Primitive(None, over),
    "rot": Primitive(None, rot),
    "-rot": Primitive(None, unrot),
    "pick": Primitive(None, pick),
    ".": Primitive(None, dot),
    "putc": Primitive(None, putc),
    "bytes.new": Primitive(None, bytes_new),
    "bytes.clear": Primitive(None, bytes_clear),
    "bytes.length": Primitive(None, bytes_length),
    "b%": Primitive(None, bytes_push),
    "b@": Primitive(None, bytes_get),
    "b!": Primitive(None, bytes_set),
    "file.read": Primitive(None, file_read),
    "block.new": Primitive(None, block_new),
    "@": Primitive(None, pointer_get),
    "!": Primitive(None, pointer_set),
    "+p": Primitive(None, pointer_offset),
}
