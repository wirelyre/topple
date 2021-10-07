import re
import sys

comment = re.compile("#.*")
octet = re.compile("[0-9A-F]{2}")

while (line := sys.stdin.readline()) != "":
    line = comment.sub("", line)

    for b in octet.findall(line):
        b = int(b, base=16)
        sys.stdout.buffer.write(bytes([b]))

sys.stdout.buffer.flush()
