from copy import copy
import re

from runtime import (
    Call,
    Cell,
    Close,
    Condition,
    Definition,
    Exit,
    Get,
    Primitive,
    Literal,
    Loop,
    Open,
    Set,
    String,
)
from tokens import tokens


def is_kw(tok):
    return tok.value in {
        ":",
        ";",
        "exit",
        "if",
        "else",
        "then",
        "begin",
        "while",
        "repeat",
        "constant",
        "variable",
        "type",
    }


def parse(filename, source, prims, defs):
    it = tokens(filename, source)
    main = []

    for t in it:
        if t.value == ":":
            parse_def(t, it, prims, defs)

        elif t.value == "constant":
            main.append(parse_const(t, it, prims, defs))

        elif t.value == "variable":
            parse_var(t, it, prims, defs)

        elif t.value == "type":
            parse_type(t, it, prims, defs)

        elif is_kw(t):
            raise Exception("TODO")

        else:
            main.append(parse_word(t, prims, defs))

    return main


def insert_def(name, value, prims, defs):
    if name in prims or name in defs:
        raise Exception("TODO")
    defs[name] = value


def parse_word(tok, prims, defs):
    if tok.value in prims:
        prim = copy(prims[tok.value])
        prim.token = tok
        return prim

    if tok.value in defs:
        return Call(tok, defs[tok.value])

    if tok.value.isdecimal():
        num = int(tok.value)
        if num & 0xFFFF_FFFF_FFFF_FFFF == num:
            return Literal(tok, num)

    if is_kw(tok):
        raise Exception("TODO")
    else:
        raise Exception("TODO")


def parse_word_or_control(tok, it, prims, defs):
    if tok.value[0] == '"':
        return String(tok, tok.value[1:-1])

    if tok.value == "exit":
        return Exit(tok)

    if tok.value == "if":
        return parse_cond(tok, it, prims, defs)

    if tok.value == "begin":
        return parse_loop(tok, it, prims, defs)

    return parse_word(tok, prims, defs)


def parse_def(_colon_tok, it, prims, defs):
    name_tok = next(it)
    name = name_tok.value
    contents = []

    insert_def(name, Definition(name_tok, name, contents), prims, defs)

    for t in it:
        if t.value == ";":
            return

        contents.append(parse_word_or_control(t, it, prims, defs))


def parse_const(_const_tok, it, prims, defs):
    name_tok = next(it)
    name = name_tok.value

    cell = Cell()
    insert_def(name, Get(name_tok, cell), prims, defs)
    return Set(name_tok, cell)


def parse_var(_var_tok, it, prims, defs):
    name_tok = next(it)
    name = name_tok.value

    getter = name + "@"
    setter = name + "!"

    cell = Cell()
    insert_def(getter, Get(name_tok, cell), prims, defs)
    insert_def(setter, Set(name_tok, cell), prims, defs)


def parse_type(_type_tok, it, prims, defs):
    name_tok = next(it)
    name = name_tok.value

    opener = "<" + name
    closer = ">" + name

    insert_def(opener, Open(name_tok, name), prims, defs)
    insert_def(closer, Close(name_tok, name), prims, defs)


def parse_cond(if_tok, it, prims, defs):
    if_true = []
    if_false = []

    for t in it:
        if t.value == "else":
            break
        if t.value == "then":
            return Condition(if_tok, if_true, if_false)

        if_true.append(parse_word_or_control(t, it, prims, defs))

    for t in it:
        if t.value == "then":
            return Condition(if_tok, if_true, if_false)

        if_false.append(parse_word_or_control(t, it, prims, defs))

    raise Exception("TODO")


def parse_loop(_begin_tok, it, prims, defs):
    test = []
    body = []
    while_tok = None

    for t in it:
        if t.value == "while":
            while_tok = t
            break

        test.append(parse_word_or_control(t, it, prims, defs))

    for t in it:
        if t.value == "repeat":
            return Loop(while_tok, test, body)

        body.append(parse_word_or_control(t, it, prims, defs))

    raise Exception("TODO")
