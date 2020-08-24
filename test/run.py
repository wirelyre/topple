#!/usr/bin/env python3

from pathlib import Path
import re
import subprocess
import sys

tests = sorted(Path("test").glob("*.tpl"))


def c_interpreter(test):
    try:
        with open(test, "rb") as t:
            return subprocess.check_output(
                ["build/topple-c"], stdin=t, stderr=subprocess.STDOUT
            )
    except:
        return None


def python_interpreter(source):
    try:
        with open(test, "rb") as t:
            return subprocess.check_output(
                [sys.executable, "src/python/topple.py"],
                stdin=t,
                stderr=subprocess.STDOUT,
            )
    except:
        return None


ERROR = re.compile(br"\\ ERROR")
OK = re.compile(br"\\ OK -- ?(.*)")
unexpected = []

for test in tests:
    source = test.read_bytes()

    if ERROR.match(source) is not None:
        expected = None

    else:
        ok = OK.match(source)

        if ok is None:
            print("test has the wrong format: ", test)
            continue

        expected = ok.group(1)

    def start(lang, test):
        print("{:<8} {:<15} ... ".format("[" + lang + "]", str(test)), end="")

    def end(lang, test, expected, found):
        global unexpected
        if expected == found:
            print("OK")
        else:
            print("ERROR")
            unexpected.append((lang, test, expected, found))

    start("C", test)
    end("C", test, expected, c_interpreter(test))
    start("Python", test)
    end("Python", test, expected, python_interpreter(test))


if len(unexpected) == 0:
    print("all passed!")
    sys.exit(0)


print()
print(f"errors: ({len(unexpected)} total)")

for lang, test, expected, found in unexpected:
    format = lambda x: "failure" if x is None else str(x)

    print()
    print(f"[{lang}] {test}:")
    print(f"expected {format(expected)}")
    print(f"found {format(found)}")

sys.exit(1)
