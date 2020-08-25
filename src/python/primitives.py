from sys import exit, stderr
from typing import Any

from runtime import ArithPrim, Pointer, Primitive
from util import ToppleException


add = lambda l, r: l + r
sub = lambda l, r: l - r
mul = lambda l, r: l * r
div = lambda l, r: l // r

shl = lambda l, r: l << (r % 64)
shr = lambda l, r: l >> (r % 64)
and_ = lambda l, r: l & r
or_ = lambda l, r: l | r
xor = lambda l, r: l ^ r

eq = lambda l, r: l == r
ne = lambda l, r: l != r
lt = lambda l, r: l < r
gt = lambda l, r: l > r
le = lambda l, r: l <= r
ge = lambda l, r: l >= r


def not_(s):
    with s.pop([int]) as [v]:
        s.append([~v & 0xFFFF_FFFF_FFFF_FFFF])


def dup(s):
    with s.pop([Any]) as [v]:
        s.append([v, v])


def drop(s):
    with s.pop([Any]):
        pass


def swap(s):
    with s.pop([Any, Any]) as [v0, v1]:
        s.append([v1, v0])


def nip(s):
    with s.pop([Any, Any]) as [_, v]:
        s.append([v])


def tuck(s):
    with s.pop([Any, Any]) as [v0, v1]:
        s.append([v1, v0, v1])


def over(s):
    with s.pop([Any, Any]) as [v0, v1]:
        s.append([v0, v1, v0])


def rot(s):
    with s.pop([Any, Any, Any]) as [v0, v1, v2]:
        s.append([v1, v2, v0])


def unrot(s):
    with s.pop([Any, Any, Any]) as [v0, v1, v2]:
        s.append([v2, v0, v1])


def pick(s):
    with s.pop([int]) as [n]:
        v = s.pick(n)
        s.append([v])


def dot(s):
    with s.pop([int]) as [n]:
        print(n, end=" ", file=stderr)


def putc(s):
    with s.pop([int]) as [n]:
        c = chr(n)
        if (c.isascii() and c.isprintable()) or c == " " or c == "\n":
            print(c, end="", file=stderr)
        else:
            raise ToppleException("unprintable character")


def fail(s):
    with s.pop([int]) as [n]:
        exit(n)


def bytes_new(s):
    s.append([bytearray()])


def bytes_clear(s):
    with s.pop([bytearray]) as [b]:
        b.clear()


def bytes_length(s):
    with s.pop([bytearray]) as [b]:
        l = len(b) & 0xFFFF_FFFF_FFFF_FFFF
        s.append([l])


def bytes_push(s):
    with s.pop([int, bytearray]) as [c, b]:
        b.append(c & 0xFF)


def bytes_get(s):
    with s.pop([int, bytearray]) as [idx, b]:
        c = b[idx]
        s.append([c])


def bytes_set(s):
    with s.pop([int, int, bytearray]) as [c, idx, b]:
        b[idx] = c


def file_read(s):
    with s.pop([bytearray]) as [filename]:
        try:
            with open(bytes(filename), "rb") as file:
                contents = file.read()
                s.append([bytearray(contents)])
        except IOError:
            s.append([0])


def block_new(s):
    s.append([Pointer()])


def pointer_get(s):
    with s.pop([Pointer]) as [p]:
        s.append([p.get()])


def pointer_set(s):
    with s.pop([Any, Pointer]) as [v, p]:
        p.set(v)


def pointer_offset(s):
    with s.pop([Pointer, int]) as [p, offset]:
        s.append([p.with_offset(offset)])


primitives = {
    "+": ArithPrim(None, add),
    "-": ArithPrim(None, sub),
    "*": ArithPrim(None, mul),
    "/": ArithPrim(None, div),
    "<<": ArithPrim(None, shl),
    ">>": ArithPrim(None, shr),
    "not": Primitive(None, not_),
    "and": ArithPrim(None, and_),
    "or": ArithPrim(None, or_),
    "xor": ArithPrim(None, xor),
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
    "fail": Primitive(None, fail),
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
