from sys import stderr
from typing import Any

from runtime import ArithPrim, Primitive


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
}
