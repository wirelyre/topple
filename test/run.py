#!/usr/bin/env python3

from pathlib import Path
import re
import subprocess
import sys

tests = sorted(Path("test").glob("*.tpl"))

impl_align = 2 + max(
    len(impl)
    for impl in [
        "C",
        "Python",
        "simple-Py2",
        "simple-Py3",
        "wasm",
    ]
)
test_align = max(len(str(test)) for test in tests)
format_str = "{:<" + str(impl_align) + "} {:<" + str(test_align) + "} ... "


def c_interpreter(test):
    try:
        with open(test, "rb") as t:
            return subprocess.check_output(
                ["build/topple-c"], stdin=t, stderr=subprocess.STDOUT
            )
    except:
        return None


def python_interpreter(test):
    try:
        return subprocess.check_output(
            [sys.executable, "src/python/topple.py", test], stderr=subprocess.STDOUT
        )
    except:
        return None


def simple_interpreter(test, executable):
    try:
        with open(test, "rb") as t:
            compiled = subprocess.check_output(
                [executable, "src/simple.py"], stdin=t, stderr=subprocess.STDOUT
            )

        p = subprocess.Popen(
            [executable, "-"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

        (stdout, _stderr) = p.communicate(compiled)

        if p.wait() == 0:
            return stdout
        else:
            return None

    except:
        return None


def wasm(test):
    try:
        subprocess.check_output(
            [sys.executable, "build/topple-wasm.py", "-o", "build/test.tmp.wasm", test]
        )

        return subprocess.check_output(
            ["wasm3", "build/test.tmp.wasm"],
            stderr=subprocess.STDOUT,
        )

    except:
        return None

    finally:
        Path("build/test.tmp.wasm").unlink(missing_ok=True)
        pass


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
        print(format_str.format("[" + lang + "]", str(test)), end="")

    def end(lang, test, expected, found):
        global unexpected
        if expected == found:
            print("OK")
        else:
            print("ERROR")
            unexpected.append((lang, test, expected, found))

    # start("C", test)
    # end("C", test, expected, c_interpreter(test))
    # start("Python", test)
    # end("Python", test, expected, python_interpreter(test))
    # start("simple-Py2", test)
    # end("simple-Py2", test, expected, simple_interpreter(test, "python2"))
    # start("simple-Py3", test)
    # end("simple-Py3", test, expected, simple_interpreter(test, "python3"))
    start("wasm", test)
    end("wasm", test, expected, wasm(test))


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
