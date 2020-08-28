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
    Token,
)
from util import ParseException, tokens


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
            raise ParseException("unexpected keyword outside definition", t)

        else:
            main.append(parse_word(t, prims, defs))

    return main


def insert_def(tok, value, prims, defs):
    name = tok.value

    if is_kw(tok):
        raise ParseException("redefinition of keyword", tok)
    if name in prims:
        raise ParseException("redefinition of primitive", tok)
    if name in defs:
        raise ParseException("redefinition of word", tok, defs[name].token.location)

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
        raise ParseException("unexpected keyword", tok)
    else:
        raise ParseException("undefined word", tok)


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


def require_name(it, tok):
    try:
        return next(it)
    except StopIteration:
        raise ParseException("expected name", tok)


def parse_def(colon_tok, it, prims, defs):
    name = require_name(it, colon_tok)
    contents = []

    insert_def(name, Definition(name, contents), prims, defs)

    for t in it:
        if t.value == ";":
            return

        contents.append(parse_word_or_control(t, it, prims, defs))

    raise ParseException("unterminated definition", name)


def parse_const(const_tok, it, prims, defs):
    name = require_name(it, const_tok)

    cell = Cell()
    insert_def(name, Get(name, cell), prims, defs)
    return Set(name, cell)


def parse_var(var_tok, it, prims, defs):
    name = require_name(it, var_tok)

    getter = Token(value=name.value + "@", location=var_tok.location)
    setter = Token(value=name.value + "!", location=var_tok.location)

    cell = Cell()
    insert_def(getter, Get(name, cell), prims, defs)
    insert_def(setter, Set(name, cell), prims, defs)


def parse_type(type_tok, it, prims, defs):
    name = require_name(it, type_tok)

    opener = Token(value="<" + name.value, location=type_tok.location)
    closer = Token(value=">" + name.value, location=type_tok.location)

    insert_def(opener, Open(name, name.value), prims, defs)
    insert_def(closer, Close(name, name.value), prims, defs)


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

    raise ParseException("unterminated conditional", if_tok)


def parse_loop(begin_tok, it, prims, defs):
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

    raise ParseException("unterminated loop", begin_tok)
