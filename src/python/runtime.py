from contextlib import contextmanager
from copy import copy
from dataclasses import dataclass
from sys import stderr
from typing import Any, Callable, Optional

from util import Token, ToppleException, trace


def name_type(value_or_type):
    if value_or_type == Pointer:
        return "pointer"
    elif isinstance(value_or_type, str):
        return f"'{value_or_type}'"

    elif isinstance(value_or_type, Pointer):
        if value_or_type.type is None:
            return "pointer"
        else:
            return f"'{value_or_type.type}'"

    elif value_or_type == int or isinstance(value_or_type, int):
        return "integer"

    elif value_or_type == bytearray or isinstance(value_or_type, bytearray):
        return "bytes"


def ensure_type(value, type):
    if type is Any:
        return

    elif isinstance(type, str):
        if isinstance(value, Pointer) and value.type == type:
            return
        else:
            pass

    elif type == Pointer:
        if isinstance(value, Pointer) and value.type is None:
            return
        else:
            pass

    elif isinstance(value, type):
        return

    raise ToppleException(
        "type mismatch", hint=f"expected {name_type(type)}, found {name_type(value)}"
    )


class EarlyExit(Exception):
    pass


class Stack(list):
    def append(self, vs):
        if len(self) + len(vs) > 10_000:
            raise ToppleException("stack overflow")

        for v in vs:
            if isinstance(v, bool):
                v = 0xFFFF_FFFF_FFFF_FFFF if v else 0
            super().append(v)

    @contextmanager
    def pop(self, types):
        try:
            if len(types) == 0:
                return []

            popped = self[-len(types) :]
            for _ in popped:
                super().pop()

            if len(popped) < len(types):
                word = "value" if len(types) == 1 else "values"
                raise ToppleException(
                    "stack underflow", hint=f"expected {len(types)} {word}"
                )

            for v, ty in zip(popped, types):
                ensure_type(v, ty)

            yield popped

        except ToppleException as e:
            e.captured_stack = popped
            raise e

    def pick(self, n):
        if len(self) < n + 1:
            raise ToppleException("stack underflow")
        return self[-(n + 1)]

    def top_truthy(self):
        with self.pop([Any]) as [v]:
            return v != 0


class Pointer:
    block: list
    idx: int
    type: Optional[str]

    def __init__(self):
        self.block = [None] * 400
        self.idx = 0
        self.type = None

    def __str__(self):
        return f"{name_type(self)} (offset {self.idx})"

    def with_offset(self, offset):
        idx = (self.idx + offset) & 0xFFFF_FFFF_FFFF_FFFF

        if idx >= 400:
            raise ToppleException("pointer out of bounds")

        p = copy(self)
        p.idx = idx
        return p

    def get(self):
        v = self.block[self.idx]
        if v is None:
            raise ToppleException("uninitialized data")
        return v

    def set(self, v):
        self.block[self.idx] = v

    def close(self, type):
        p = copy(self)
        p.type = type
        return p

    def open(self):
        p = copy(self)
        p.type = None
        return p


@dataclass
class Cell:
    value: Any = None


@dataclass
class Node:
    token: Optional[Token]


@dataclass
class Literal(Node):
    value: int

    def run(self, stack):
        with trace(self.token):
            stack.append([self.value])


@dataclass
class Get(Node):
    cell: Cell

    def run(self, stack):
        with trace(self.token):
            if self.cell.value is None:
                raise ToppleException("uninitialized data")
            stack.append([self.cell.value])


@dataclass
class Set(Node):
    cell: Cell

    def run(self, stack):
        with trace(self.token):
            with stack.pop([Any]) as [v]:
                self.cell.value = v


@dataclass
class Open(Node):
    type: str

    def run(self, stack):
        with trace(self.token):  # TODO
            with stack.pop([self.type]) as [p]:
                stack.append([p.open()])


@dataclass
class Close(Node):
    type: str

    def run(self, stack):
        with trace(self.token):  # TODO
            with stack.pop([Pointer]) as [p]:
                stack.append([p.close(self.type)])


@dataclass
class Primitive(Node):
    action: Callable[[Stack], None]

    def run(self, stack):
        with trace(self.token):
            self.action(stack)


@dataclass
class String(Node):
    value: str

    def run(self, _stack):
        print(self.value, end="", file=stderr)


@dataclass
class Definition(Node):
    contents: list

    def run(self, stack):
        for node in self.contents:
            node.run(stack)


@dataclass
class Call(Node):
    word: Definition

    def run(self, stack):
        with trace(self.token):
            try:
                self.word.run(stack)
            except EarlyExit:
                pass


@dataclass
class Exit(Node):
    def run(self, stack):
        raise EarlyExit


@dataclass
class Condition(Node):
    if_true: list
    if_false: list

    def run(self, stack):
        with trace(self.token):
            if stack.top_truthy():
                to_run = self.if_true
            else:
                to_run = self.if_false

        for node in to_run:
            node.run(stack)


@dataclass
class Loop(Node):
    test: list
    body: list

    def run(self, stack):
        while True:
            for node in self.test:
                node.run(stack)

            with trace(self.token):
                if not stack.top_truthy():
                    break

            for node in self.body:
                node.run(stack)


@dataclass
class ArithPrim(Node):
    action: Callable[[int, int], int]

    def run(self, stack):
        with trace(self.token):
            with stack.pop([int, int]) as [l, r]:
                try:
                    stack.append([self.action(l, r) & 0xFFFF_FFFF_FFFF_FFFF])
                except ZeroDivisionError:
                    raise ToppleException("division by zero")


@dataclass
class BoolPrim(Node):
    action: Callable[[int, int], int]

    def run(self, stack):
        with trace(self.token):
            with stack.pop([int, int]) as [l, r]:
                n = 0xFFFF_FFFF_FFFF_FFFF if self.action(l, r) else 0
                stack.append([n])
