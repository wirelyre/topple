from dataclasses import dataclass
import re


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


@dataclass
class Token:
    value: str
    location: Location


WHITESPACE = re.compile(
    r""" ^(
        [ \n] |     # whitespace or
        \\ [^\n]*   # a comment
    )* """,
    re.X,
)
STRCHAR = re.compile(r"[^\\]|\\.")
STRING = re.compile(r'^"([^\\]|\\.)*?"')
WORD = re.compile("^[!#-\[\]-~]+")


def tokens(filename: str, code: str):
    loc = Location(filename)

    while len(code) > 0:
        ws = WHITESPACE.match(code)
        if ws is not None:
            code = code[ws.end() :]
            loc = loc.advanced(ws.group(0))

        s = STRING.match(code)
        w = WORD.match(code)

        if s is not None:
            yield Token(value=unescape(s.group(0)), location=loc)
            code = code[s.end() :]
            loc = loc.advanced(s.group(0))

        elif w is not None:
            yield Token(value=w.group(0), location=loc)
            code = code[w.end() :]
            loc = loc.advanced(w.group(0))

        elif code != "":
            raise Exception("TODO")


def unescape(s):
    def char(s):
        if s == r"\n":
            return "\n"
        if s == r"\\":
            return "\\"
        if s == r"\"":
            return '"'

        if s[0] == "\\":
            raise Exception("TODO")

        return s

    return "".join(char(match.group(0)) for match in STRCHAR.finditer(s))
