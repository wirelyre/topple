from contextlib import contextmanager
from dataclasses import dataclass
import re


class ParseException(Exception):
    pass


@dataclass
class Location:
    file: str
    row: int = 1
    col: int = 1

    def advanced(self, by: str):
        row = self.row
        col = self.col

        for c in by:
            if c == "\n":
                row += 1
                col = 1
            else:
                col += 1

        return Location(file=self.file, row=row, col=col)

    def __str__(self):
        return f"{self.file}:{self.row}:{self.col}"


@dataclass
class Token:
    value: str
    location: Location

    def __str__(self):
        return f"{self.value} ({self.location})"


LEGAL = re.compile(r"[ \n!-~]*")
WHITESPACE = re.compile(
    r""" (
        [ \n] |     # whitespace or
        \\ [^\n]*   # a comment
    )* """,
    re.X,
)
STRCHAR = re.compile(r"[^\\]|\\.")
STRING = re.compile(r'"([^\\]|\\.)*?"')
WORD = re.compile("[!#-\[\]-~]+")


def tokens(filename: str, code: str):
    loc = Location(filename)

    if not LEGAL.fullmatch(code):
        m = LEGAL.match(code)
        end = 0

        if m is not None:
            loc = loc.advanced(m.group(0))
            end = m.end()

        raise ParseException(
            "illegal character", Token(value=code[end], location=loc),
        )

    while len(code) > 0:
        ws = WHITESPACE.match(code)
        if ws is not None:
            code = code[ws.end() :]
            loc = loc.advanced(ws.group(0))

        s = STRING.match(code)
        w = WORD.match(code)

        if s is not None:
            yield Token(value=unescape(s.group(0), loc), location=loc)
            code = code[s.end() :]
            loc = loc.advanced(s.group(0))

        elif w is not None:
            yield Token(value=w.group(0), location=loc)
            code = code[w.end() :]
            loc = loc.advanced(w.group(0))

        elif code != "":
            raise ParseException(
                "unterminated string", Token(value=code[0], location=loc)
            )


def unescape(s, loc):
    def char(s):
        if s == r"\"":
            return '"'
        if s == r"\\":
            return "\\"
        if s == r"\n":
            return "\n"

        if s[0] == "\\":
            raise ParseException(
                "illegal escape sequence in string", Token(value=s, location=loc)
            )

        return s

    return "".join(char(match.group(0)) for match in STRCHAR.finditer(s))


class ToppleException(Exception):
    def __init__(self, error, hint=None):
        super().__init__(error)
        self.backtrace = []
        self.captured_stack = []
        self.hint = hint


@contextmanager
def trace(name):
    try:
        yield
    except ToppleException as e:
        e.backtrace.append(name)
        raise e
