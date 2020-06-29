from dataclasses import dataclass
from sys import stderr
from typing import Any, Callable, Optional

from tokens import Token


class Stack(list):
    def append(self, vs):
        if len(self) + len(vs) > 10_000:
            raise Exception("TODO")

        for v in vs:
            if isinstance(v, bool):
                v = 0xFFFF_FFFF_FFFF_FFFF if v else 0
            super().append(v)

    def pop(self, types):
        if len(types) == 0:
            return []

        if len(self) < len(types):
            raise Exception("TODO")

        popped = self[-len(types) :]
        for v, ty in zip(popped, types):
            if ty is not Any and not isinstance(v, ty):
                raise Exception("TODO")

        for _ in types:
            super().pop()

        return popped

    def pick(self, n):
        if len(self) < n + 1:
            raise Exception("TODO")
        return self[-(n + 1)]

    def top_truthy(self):
        [v] = self.pop([Any])
        return v != 0


@dataclass
class Node:
    token: Optional[Token]


@dataclass
class Literal(Node):
    value: int

    def run(self, stack):
        stack.append([self.value])


@dataclass
class Primitive(Node):
    action: Callable[[Stack], None]

    def run(self, stack):
        self.action(stack)


@dataclass
class String(Node):
    value: str

    def run(self, _stack):
        print(self.value, end="", file=stderr)


@dataclass
class Definition(Node):
    name: str
    contents: list

    def run(self, stack):
        for node in self.contents:
            node.run(stack)


@dataclass
class Call(Node):
    word: Definition

    def run(self, stack):
        self.word.run(stack)


@dataclass
class Condition(Node):
    if_true: list
    if_false: list

    def run(self, stack):
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

            if not stack.top_truthy():
                break

            for node in self.body:
                node.run(stack)


@dataclass
class ArithPrim(Node):
    action: Callable[[int, int], int]

    def run(self, stack):
        [l, r] = stack.pop([int, int])
        stack.append([self.action(l, r) & 0xFFFF_FFFF_FFFF_FFFF])
